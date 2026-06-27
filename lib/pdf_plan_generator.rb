# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

# PDFPlanGenerator — generates a 6-page PDF enclosure plan using Prawn.
# Pages: Cover, Front View, Side Views, Panel Index, Cut List, Nesting.
module PDFPlanGenerator
  # Build the full PDF plan and save to output_dir.
  # @param design [Hash] from EnclosureCalculator.design
  # @param panels [Array<Panel>]
  # @param sheets [Array<Hash>] nesting sheets
  # @param usage [Hash] material usage summary
  # @param config [EnclosureConfig]
  # @param client_name [String]
  # @param output_dir [String]
  # @return [String] path to PDF file
  def self.generate(design, panels, sheets, usage, config, client_name, output_dir)
    Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

    safe_name = (client_name || 'JwBox').gsub(/[^a-zA-Z0-9_-]/, '_')
    pdf_path = File.join(output_dir, "#{safe_name}_plan.pdf")

    # Build shared context
    ctx = build_ctx(design, panels, sheets, usage, config, client_name)

    Prawn::Document.generate(pdf_path, page_size: 'LETTER', page_layout: :landscape) do |pdf|
      pdf.font 'Helvetica'

      cover_page(pdf, ctx)
      pdf.start_new_page
      front_view(pdf, ctx)
      pdf.start_new_page
      side_views(pdf, ctx)
      pdf.start_new_page
      panel_index(pdf, ctx)
      pdf.start_new_page
      cut_list_page(pdf, ctx)
      pdf.start_new_page
      nesting_page(pdf, ctx)
    end

    pdf_path
  end

  # ---- Context builder ----

  def self.build_ctx(design, panels, sheets, usage, config, client_name)
    {
      design: design,
      panels: panels,
      sheets: sheets,
      usage: usage,
      config: config,
      client_name: client_name || 'JwBox Project',
      date: Time.now.strftime('%Y-%m-%d'),
      type_label: design[:enclosure_type].to_s.upcase.gsub('_', ' ')
    }
  end

  # ---- Shared header ----

  def self.draw_header(pdf, title, ctx)
    pdf.fill_color '333333'
    pdf.text "#{ctx[:client_name]} — #{title}", size: 16, style: :bold
    pdf.text "Type: #{ctx[:type_label]}  |  Date: #{ctx[:date]}", size: 9, color: '666666'
    pdf.move_down 8
    pdf.stroke_color '999999'
    pdf.stroke_horizontal_rule
    pdf.move_down 12
  end

  # ---- Page 1: Cover ----

  def self.cover_page(pdf, ctx)
    pdf.move_down 80
    pdf.fill_color '1a1a2e'
    pdf.text 'JwBox', size: 48, style: :bold, align: :center
    pdf.move_down 8
    pdf.fill_color '333333'
    pdf.text 'Subwoofer Enclosure Design Plan', size: 20, align: :center
    pdf.move_down 20
    pdf.fill_color '555555'
    pdf.text "Client: #{ctx[:client_name]}", size: 12, align: :center
    pdf.text "Date:   #{ctx[:date]}", size: 12, align: :center
    pdf.text "Type:   #{ctx[:type_label]}", size: 12, align: :center
    pdf.move_down 30
    pdf.fill_color '333333'

    d = ctx[:design]
    info = [
      ['External', "#{d[:external][:width]} x #{d[:external][:height]} x #{d[:external][:depth]} in"],
      ['Internal', "#{d[:internal][:width].round(2)} x #{d[:internal][:height].round(2)} x #{d[:internal][:depth].round(2)} in"],
      ['Net Volume', "#{d[:net_volume_cu_ft]} cu ft"],
      ['Per Sub', "#{d[:per_sub_cu_ft]} cu ft"],
      ['Panels', "#{ctx[:panels].size}"]
    ]
    info << ['Tuning', "#{d[:port][:actual_tuning]} Hz"] if d[:port]
    info << ['Sheets', "#{ctx[:usage][:sheet_count]} (4x8)"]

    pdf.table(info, position: :center, cell_style: { borders: [], padding: [4, 12] }) do
      column(0).font_style = :bold
    end
  end

  # ---- Page 2: Front View ----

  def self.front_view(pdf, ctx)
    draw_header(pdf, 'Front View', ctx)
    d = ctx[:design]

    pdf.bounding_box([60, pdf.cursor], width: pdf.bounds.width - 120, height: pdf.bounds.height - 80) do
      scale = 3.0
      w = d[:external][:width] * scale
      h = d[:external][:height] * scale
      x0 = (pdf.bounds.width - w) / 2
      y0 = (pdf.bounds.height - h) / 2

      pdf.fill_color 'ffffff'
      pdf.stroke_color '000000'
      pdf.line_width = 2
      pdf.rectangle([x0, y0 + h], w, h)
      pdf.fill_and_stroke

      # Draw sub cutout
      baffle = d[:panels].find { |p| p.has_cutout }
      if baffle
        cutout_r = (baffle.cutout_diameter || 11.0) * scale / 2.0
        cx = x0 + w / 2.0
        cy = y0 + h / 2.0 + cutout_r
        pdf.circle_at([cx, cy], cutout_r)
        pdf.fill_and_stroke
      end

      # Dimension arrows
      pdf.stroke_color '333333'
      pdf.line_width = 1
      draw_dimension(pdf, x0, y0 - 10, x0 + w, y0 - 10, "#{d[:external][:width]}\"")
      draw_dimension(pdf, x0 - 10, y0, x0 - 10, y0 + h, "#{d[:external][:height]}\"")
    end
  end

  # ---- Page 3: Side Views ----

  def self.side_views(pdf, ctx)
    draw_header(pdf, 'Side / Top Views', ctx)
    d = ctx[:design]

    pdf.bounding_box([60, pdf.cursor], width: pdf.bounds.width - 120, height: pdf.bounds.height - 120) do
      scale = 3.0
      w = d[:external][:depth] * scale
      h = d[:external][:height] * scale
      x0 = (pdf.bounds.width - w) / 2
      y0 = pdf.bounds.height - h - 30

      # Side view
      pdf.fill_color 'ffffff'
      pdf.stroke_color '000000'
      pdf.line_width = 2
      pdf.rectangle([x0, y0 + h], w, h)
      pdf.fill_and_stroke
      draw_dimension(pdf, x0, y0 - 10, x0 + w, y0 - 10, "#{d[:external][:depth]}\" (Depth)")
      draw_dimension(pdf, x0 - 10, y0, x0 - 10, y0 + h, "#{d[:external][:height]}\" (Height)")

      # Top view below
      y_top = y0 - 40
      w_top = d[:external][:width] * scale
      x_top = (pdf.bounds.width - w_top) / 2
      pdf.rectangle([x_top, y_top + h], w_top, h)
      pdf.fill_and_stroke
      draw_dimension(pdf, x_top, y_top - 10, x_top + w_top, y_top - 10, "#{d[:external][:width]}\" (Width)")
      draw_dimension(pdf, x_top - 10, y_top, x_top - 10, y_top + h, "#{d[:external][:depth]}\" (Depth)")
    end
  end

  # ---- Page 4: Panel Index ----

  def self.panel_index(pdf, ctx)
    draw_header(pdf, 'Panel Index', ctx)
    y_start = pdf.cursor

    ctx[:panels].each_slice(2) do |pair|
      pair.each_with_index do |panel, i|
        x = i * (pdf.bounds.width / 2)
        draw_panel_thumb(pdf, panel, x, y_start, pdf.bounds.width / 2 - 10, 100)
      end
      y_start -= 110
      break if y_start < 50
    end
  end

  # ---- Page 5: Cut List ----

  def self.cut_list_page(pdf, ctx)
    draw_header(pdf, 'Cut List', ctx)

    cutlist = CutlistGenerator.generate(ctx[:panels])
    data = [['#', 'Name', 'W (in)', 'H (in)', 'Qty', 'Notes']]
    cutlist.each_with_index do |c, i|
      data << [i + 1, c[:name], format('%.2f', c[:width]), format('%.2f', c[:height]),
               c[:instance], c[:notes][0, 25]]
    end

    pdf.table(data, header: true, width: pdf.bounds.width) do
      row(0).font_style = :bold
      row(0).fill_color = 'eeeeee'
      cells.padding = 4
      cells.size = 8
    end
  end

  # ---- Page 6: Nesting ----

  def self.nesting_page(pdf, ctx)
    draw_header(pdf, 'Nesting Layout', ctx)
    usage = ctx[:usage]

    pdf.text "Sheets Required: #{usage[:sheet_count]}  |  " \
             "Efficiency: #{usage[:efficiency_pct]}%  |  " \
             "Material: #{usage[:sheet_width]} x #{usage[:sheet_length]} in", size: 10
    pdf.move_down 10

    ctx[:sheets].each_with_index do |sheet, si|
      pdf.text "Sheet #{si + 1}", size: 12, style: :bold
      pdf.move_down 4

      pdf.bounding_box([40, pdf.cursor], width: pdf.bounds.width - 80, height: 200) do
        pdf.stroke_color '000000'
        pdf.line_width = 1
        pdf.stroke_rectangle([0, pdf.bounds.height], pdf.bounds.width, pdf.bounds.height)

        sheet_scale = [pdf.bounds.width / CutlistGenerator::SHEET_W,
                       pdf.bounds.height / CutlistGenerator::SHEET_L].min * 0.95

        sheet[:placements].each do |pl|
          rx = pl[:x] * sheet_scale + (pdf.bounds.width - CutlistGenerator::SHEET_W * sheet_scale) / 2
          ry = pdf.bounds.height - (pl[:y] + pl[:h]) * sheet_scale -
               (pdf.bounds.height - CutlistGenerator::SHEET_L * sheet_scale) / 2
          rw = pl[:w] * sheet_scale
          rh = pl[:h] * sheet_scale

          pdf.fill_color 'd9e2f3'
          pdf.stroke_color '333333'
          pdf.rectangle([rx, ry + rh], rw, rh)
          pdf.fill_and_stroke

          pdf.fill_color '000000'
          pdf.text_box(pl[:name][0, 12], at: [rx, ry + rh - 2], width: rw, height: 10,
                       size: 6, overflow: :truncate) if rw > 10 && rh > 10
        end
      end

      pdf.move_down 20
      break if pdf.cursor < 100
    end
  end

  # ---- Drawing helpers ----

  def self.draw_dimension(pdf, x1, y1, x2, y2, label)
    pdf.stroke_color '333333'
    pdf.line_width = 0.8
    pdf.line([x1, y1], [x2, y2])
    pdf.stroke
    # Arrow heads
    if (x2 - x1).abs > (y2 - y1).abs
      pdf.line([x1, y1], [x1 + 4, y1 - 3])
      pdf.line([x1, y1], [x1 + 4, y1 + 3])
      pdf.line([x2, y2], [x2 - 4, y2 - 3])
      pdf.line([x2, y2], [x2 - 4, y2 + 3])
      mid_x = (x1 + x2) / 2.0
      pdf.draw_text(label, at: [mid_x - 20, y1 - 12], size: 8)
    else
      pdf.line([x1, y1], [x1 - 3, y1 + 4])
      pdf.line([x1, y1], [x1 + 3, y1 + 4])
      pdf.line([x2, y2], [x2 - 3, y2 - 4])
      pdf.line([x2, y2], [x2 + 3, y2 - 4])
      mid_y = (y1 + y2) / 2.0
      pdf.draw_text(label, at: [x1 - 30, mid_y], size: 8)
    end
  end

  def self.draw_panel_thumb(pdf, panel, x, y, w, h)
    pdf.bounding_box([x, y], width: w, height: h) do
      pdf.stroke_color '999999'
      pdf.line_width = 0.5
      pw = panel.width * 0.5
      ph = panel.height * 0.5
      px = (w - pw) / 2
      py = (h - ph) / 2

      pdf.rectangle([px, py + ph], pw, ph)
      pdf.stroke

      if panel.has_cutout
        cr = (panel.cutout_diameter || 10.0) * 0.5 / 2.0
        pdf.circle_at([px + pw / 2.0, py + ph / 2.0], cr)
        pdf.stroke
      end

      pdf.fill_color '333333'
      pdf.draw_text("#{panel.name}", at: [px, py - 2], size: 7, style: :bold)
      pdf.draw_text("#{panel.width} x #{panel.height}", at: [px, py - 14], size: 7)
    end
  end
end
