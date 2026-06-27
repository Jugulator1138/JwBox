# frozen_string_literal: true

# CutlistGenerator — turns Panel structs into a sorted cut list,
# performs guillotine bin-packing with rotation support, and produces
# a formatted text report.
module CutlistGenerator
  SHEET_W = 48.0   # inches (width)
  SHEET_L = 96.0   # inches (length)
  KERF  = 0.125    # saw kerf in inches

  # Generate a flat array of cut-list hashes from Panel structs.
  # Each entry includes the panel dimensions plus computed area.
  # @param panels [Array<Panel>]
  # @return [Array<Hash>]
  def self.generate(panels)
    list = []
    panels.each do |p|
      p.quantity.times do |i|
        list << {
          name: p.name,
          width: p.width.round(3),
          height: p.height.round(3),
          area_sq_in: p.area_sq_in,
          has_cutout: p.has_cutout,
          cutout_diameter: p.cutout_diameter,
          cutout_offset_x: p.cutout_offset_x,
          cutout_offset_y: p.cutout_offset_y,
          notes: p.notes,
          instance: i + 1
        }
      end
    end
    # Sort largest-first for better packing
    list.sort_by { |c| -c[:area_sq_in] }
  end

  # Guillotine bin-packing with rotation support.
  # Returns array of sheets, each containing placements.
  # @param panels [Array<Panel>]
  # @return [Array<Hash>]
  def self.nest(panels)
    cutlist = generate(panels)
    sheets = []

    cutlist.each do |item|
      placed = false
      item_w = item[:width]
      item_h = item[:height]

      sheets.each do |sheet|
        if try_place(sheet, item_w, item_h, item)
          placed = true
          break
        end
        # Try rotated
        if try_place(sheet, item_h, item_w, item, rotated: true)
          placed = true
          break
        end
      end

      unless placed
        sheet = new_sheet
        try_place(sheet, item_w, item_h, item) ||
          try_place(sheet, item_h, item_w, item, rotated: true)
        sheets << sheet
      end
    end

    sheets
  end

  # Summary of sheet usage.
  # @param sheets [Array<Hash>]
  # @return [Hash]
  def self.usage(sheets)
    total_area = sheets.size * SHEET_W * SHEET_L
    used_area = sheets.sum { |s| s[:used_area] }
    efficiency = total_area > 0 ? (used_area / total_area * 100.0) : 0.0

    {
      sheet_count: sheets.size,
      sheet_width: SHEET_W,
      sheet_length: SHEET_L,
      total_area_sq_in: total_area.round(2),
      used_area_sq_in: used_area.round(2),
      efficiency_pct: efficiency.round(1),
      waste_pct: (100.0 - efficiency).round(1)
    }
  end

  # Formatted text report.
  # @return [String]
  def self.text_report(cutlist, sheets, usage, design, config, client_name = '')
    lines = []
    lines << '=' * 72
    lines << 'JwBox — Subwoofer Enclosure Cut List & Design Report'
    lines << '=' * 72
    lines << ''
    lines << "Client: #{client_name}" unless client_name.empty?
    lines << "Date:   #{Time.now.strftime('%Y-%m-%d %H:%M')}"
    lines << "Type:   #{design[:enclosure_type].to_s.upcase}"
    lines << ''
    lines << '-' * 72
    lines << 'DIMENSIONS'
    lines << '-' * 72
    ext = design[:external]
    int = design[:internal]
    lines << format('External: %.2f x %.2f x %.2f in', ext[:width], ext[:height], ext[:depth])
    lines << format('Internal: %.2f x %.2f x %.2f in', int[:width], int[:height], int[:depth])
    lines << format('Gross Volume:   %.3f cu ft', design[:gross_volume_cu_ft])
    lines << format('Net Volume:     %.3f cu ft', design[:net_volume_cu_ft])
    lines << format('Per Sub:        %.3f cu ft', design[:per_sub_cu_ft])
    lines << format('Target:         %.3f cu ft', design[:target_cu_ft])
    lines << format('Meets Target:   %s', design[:meets_target] ? 'YES' : 'NO')
    lines << ''

    if design[:port]
      port = design[:port]
      lines << '-' * 72
      lines << 'PORT SPECIFICATION'
      lines << '-' * 72
      lines << format('Target Tuning:    %.1f Hz', port[:tuning_frequency])
      lines << format('Actual Tuning:   %.1f Hz', port[:actual_tuning])
      lines << format('Port Width:      %.3f in', port[:port_width])
      lines << format('Port Height:     %.3f in', port[:port_height])
      lines << format('Port Area:       %.3f sq in', port[:port_area])
      lines << format('Port Length:     %.3f in', port[:port_length])
      lines << format('Port Volume:     %.3f cu ft', port[:port_vol_cu_ft])
      lines << format('Path Type:       %s', port[:path_type].to_s)
      lines << format('Fits in Box:     %s', port[:fits_in_box] ? 'YES' : 'NO')
      lines << ''
    end

    lines << '-' * 72
    lines << 'CUT LIST'
    lines << '-' * 72
    lines << format('%-4s %-20s %10s %10s %10s %s', '#', 'Name', 'W (in)', 'H (in)', 'Area', 'Notes')
    lines << '-' * 72
    cutlist.each_with_index do |c, i|
      lines << format('%-4d %-20s %10.3f %10.3f %10.2f %s',
                      i + 1, c[:name][0, 20], c[:width], c[:height], c[:area_sq_in], c[:notes])
    end
    lines << ''

    lines << '-' * 72
    lines << 'NESTING LAYOUT'
    lines << '-' * 72
    sheets.each_with_index do |sheet, si|
      pct = sheet[:used_area] / (SHEET_W * SHEET_L) * 100.0
      lines << format('Sheet %d / %d  (used: %.1f%%)', si + 1, sheets.size, pct)
      sheet[:placements].each do |pl|
        rot = pl[:rotated] ? ' [R]' : ''
        lines << format('  %-20s at (%.2f, %.2f) size %.2f x %.2f%s',
                        pl[:name][0, 20], pl[:x], pl[:y], pl[:w], pl[:h], rot)
      end
    end
    lines << ''

    lines << '-' * 72
    lines << 'MATERIAL USAGE'
    lines << '-' * 72
    lines << format('Sheets Required: %d (%.0f x %.0f in)', usage[:sheet_count], usage[:sheet_width], usage[:sheet_length])
    lines << format('Total Area:      %.2f sq in', usage[:total_area_sq_in])
    lines << format('Used Area:       %.2f sq in', usage[:used_area_sq_in])
    lines << format('Efficiency:      %.1f%%', usage[:efficiency_pct])
    lines << format('Waste:            %.1f%%', usage[:waste_pct])
    lines << ''
    lines << '=' * 72

    lines.join("\n")
  end

  # ---- Internal helpers ----

  def self.new_sheet
    {
      free_rects: [{ x: 0.0, y: 0.0, w: SHEET_W, h: SHEET_L }],
      placements: [],
      used_area: 0.0
    }
  end

  def self.try_place(sheet, w, h, item, rotated: false)
    sheet[:free_rects].each_with_index do |rect, _ri|
      if w <= rect[:w] && h <= rect[:h]
        # Place here
        sheet[:placements] << {
          name: item[:name],
          x: rect[:x], y: rect[:y],
          w: w, h: h,
          rotated: rotated,
          instance: item[:instance]
        }
        sheet[:used_area] += w * h

        # Split remaining space (guillotine cut)
        new_rects = []
        # Right of placed piece
        if rect[:w] - w > 0.01
          new_rects << { x: rect[:x] + w, y: rect[:y], w: rect[:w] - w, h: h }
        end
        # Above placed piece
        if rect[:h] - h > 0.01
          new_rects << { x: rect[:x], y: rect[:y] + h, w: rect[:w], h: rect[:h] - h }
        end

        sheet[:free_rects].delete(rect)
        sheet[:free_rects].concat(new_rects)
        return true
      end
    end
    false
  end
end
