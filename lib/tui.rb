# frozen_string_literal: true

# TUI — Terminal UI for JwBox with live real-time calculation.
# Provides interactive menus, prompts, and instant result display.
module JwBox
  class TUI
    attr_reader :config

    def initialize
      @config = default_config
      @last_design = nil
      @last_panels = nil
    end

    # ---- Default configuration ----

    def default_config
      {
        type: :ported,
        target_volume: 2.0,
        tuning_frequency: 32,
        num_subs: 1,
        sub_size: 12,
        sub_brand: 'Skar',
        sub_model: 'VXF-12',
        max_width: 36.0,
        max_height: 18.0,
        max_depth: 18.0,
        material_thickness: 0.75,
        double_baffle: false,
        extra_bracing: true,
        separate_chambers: false,
        power_level: :sql,
        bandpass_ratio: 0.6,
        units: :imperial,
        client_name: 'JwBox Project'
      }
    end

    # ---- Start the interactive loop ----

    def start
      puts ''
      puts '========================================'
      puts '  JwBox — Subwoofer Enclosure Calculator'
      puts '========================================'
      puts ''

      loop do
        print_main_menu
        choice = gets&.strip&.downcase
        case choice
        when '1' then input_dimensions
        when '2' then input_subwoofer
        when '3' then input_build_prefs
        when '4' then input_units
        when '5' then show_results
        when '6' then generate_outputs
        when '7' then quick_calc
        when 'q', 'quit' then break
        else puts 'Invalid choice.'
        end
        puts ''
      end

      puts 'Goodbye!'
    end

    # ---- Menu display ----

    def print_main_menu
      puts '--- Main Menu ---'
      puts '[1] Dimensions'
      puts '[2] Subwoofer'
      puts '[3] Build Prefs'
      puts '[4] Units'
      puts '[5] Show Results'
      puts '[6] Generate'
      puts '[7] Quick Calc'
      puts '[Q] Quit'
      print '> '
    end

    # ---- Input: Dimensions ----

    def input_dimensions
      puts '--- Dimensions ---'
      @config[:max_width] = prompt_f('Max Width (in)', @config[:max_width])
      @config[:max_height] = prompt_f('Max Height (in)', @config[:max_height])
      @config[:max_depth] = prompt_f('Max Depth (in)', @config[:max_depth])
      @config[:material_thickness] = prompt_f('Material Thickness (in)', @config[:material_thickness])
      live_preview
    end

    # ---- Input: Subwoofer ----

    def input_subwoofer
      puts '--- Subwoofer ---'
      puts 'Known brands: Skar, Sundown, Kicker, JL Audio, Rockford Fosgate, DC Audio, American Bass, Deaf Bonce, Taramps'
      print 'Brand (or press Enter for list): '
      brand = gets&.strip
      if brand.nil? || brand.empty?
        SubwooferDB.list_all.each { |s| puts "  #{s[:brand]} #{s[:model]} (#{s[:size]}\")" }
        print 'Brand: '
        brand = gets&.strip
      end

      print 'Model: '
      model = gets&.strip
      sub = SubwooferDB.find("#{brand} #{model}")

      if sub
        puts "Found: #{sub[:brand]} #{sub[:model]} (#{sub[:size]}\")"
        @config[:sub_size] = sub[:size]
        @config[:sub_brand] = sub[:brand]
        @config[:sub_model] = sub[:model]
        @config[:target_volume] = sub[:ported]
        @config[:tuning_frequency] = sub[:tune]
      else
        size = SubwooferDB.extract_size(model) || prompt_i('Size (in)', 12)
        sub = SubwooferDB.default_for_size(size)
        puts "Using generic #{size}\" defaults."
        @config[:sub_size] = size
        @config[:sub_brand] = 'Generic'
        @config[:sub_model] = "#{size}\""
        @config[:target_volume] = sub[:ported]
        @config[:tuning_frequency] = sub[:tune]
      end

      @config[:num_subs] = prompt_i('Quantity', @config[:num_subs])
      live_preview
    end

    # ---- Input: Build Preferences ----

    def input_build_prefs
      puts '--- Build Preferences ---'

      print 'Type (sealed/ported/bandpass) [ported]: '
      t = gets&.strip&.downcase&.to_sym
      @config[:type] = %i[sealed ported bandpass bandpass_4th].include?(t) ? t : :ported
      @config[:type] = :bandpass_4th if @config[:type] == :bandpass

      @config[:target_volume] = prompt_f('Target Volume (cu ft per sub)', @config[:target_volume])
      @config[:tuning_frequency] = prompt_f('Tuning Frequency (Hz)', @config[:tuning_frequency])

      print 'Power Level (daily/sql/spl) [sql]: '
      pl = gets&.strip&.downcase&.to_sym
      @config[:power_level] = %i[daily sql spl].include?(pl) ? pl : :sql

      @config[:double_baffle] = prompt_y('Double Baffle?', @config[:double_baffle])
      @config[:extra_bracing] = prompt_y('Extra Bracing?', @config[:extra_bracing])
      @config[:separate_chambers] = prompt_y('Separate Chambers?', @config[:separate_chambers])

      if @config[:type] == :bandpass_4th
        @config[:bandpass_ratio] = prompt_f('Bandpass Ratio (ported/total)', @config[:bandpass_ratio])
      end

      live_preview
    end

    # ---- Input: Units ----

    def input_units
      current = @config[:units]
      puts "Current units: #{current}"
      print 'Toggle to (imperial/metric)? '
      u = gets&.strip&.downcase&.to_sym
      if u == :metric || u == :imperial
        @config[:units] = u
        puts "Units set to #{u}."
      else
        puts 'No change.'
      end
      live_preview
    end

    # ---- Live preview (compact) ----

    def live_preview
      begin
        cfg = current_cfg
        design = EnclosureCalculator.design(cfg)
        @last_design = design
        @last_panels = design[:panels]

        puts ''
        puts '--- Live Preview ---'
        puts "Type: #{design[:enclosure_type]}"
        puts "External: #{fmt(design[:external][:width], :length)} x #{fmt(design[:external][:height], :length)} x #{fmt(design[:external][:depth], :length)}"
        puts "Net Vol: #{fmt(design[:net_volume_cu_ft], :volume)} | Per Sub: #{fmt(design[:per_sub_cu_ft], :volume)}"
        if design[:port]
          puts "Port: #{fmt(design[:port][:actual_tuning], :freq)} | Slot: #{fmt(design[:port][:port_width], :length)} x #{fmt(design[:port][:port_height], :length)} x #{fmt(design[:port][:port_length], :length)}"
          puts "Fits: #{design[:port][:fits_in_box] ? 'YES' : 'NO'} | Path: #{design[:port][:path_type]}"
        end
        puts "Panels: #{design[:panels].size}"
        puts '---------------------'
      rescue StandardError => e
        puts "Preview error: #{e.message}"
      end
    end

    # ---- Show detailed results ----

    def show_results
      if @last_design.nil?
        live_preview
      end
      return unless @last_design

      d = @last_design
      puts ''
      puts '=' * 50
      puts 'DETAILED RESULTS'
      puts '=' * 50
      puts "Enclosure Type: #{d[:enclosure_type]}"
      puts "External: #{d[:external][:width]} x #{d[:external][:height]} x #{d[:external][:depth]} in"
      puts "Internal: #{d[:internal][:width].round(2)} x #{d[:internal][:height].round(2)} x #{d[:internal][:depth].round(2)} in"
      puts "Gross Volume: #{d[:gross_volume_cu_ft]} cu ft"
      puts "Net Volume:   #{d[:net_volume_cu_ft]} cu ft"
      puts "Per Sub:      #{d[:per_sub_cu_ft]} cu ft"
      puts "Target:       #{d[:target_cu_ft]} cu ft"
      puts "Meets Target: #{d[:meets_target] ? 'YES' : 'NO'}"

      if d[:port]
        p = d[:port]
        puts ''
        puts 'Port:'
        puts "  Tuning:  #{p[:actual_tuning]} Hz (target #{p[:tuning_frequency]})"
        puts "  Slot:    #{p[:port_width]} x #{p[:port_height]} in"
        puts "  Length:  #{p[:port_length]} in"
        puts "  Area:    #{p[:port_area]} sq in"
        puts "  Volume:  #{p[:port_vol_cu_ft]} cu ft"
        puts "  Path:    #{p[:path_type]}"
        puts "  Fits:    #{p[:fits_in_box] ? 'YES' : 'NO'}"
      end

      puts ''
      puts 'Panels:'
      @last_panels&.each do |panel|
        cutout_info = panel.has_cutout ? " (cutout #{panel.cutout_diameter}\")" : ''
        puts "  #{panel.name}: #{panel.width} x #{panel.height} in#{cutout_info} x#{panel.quantity}"
      end
    end

    # ---- Generate outputs ----

    def generate_outputs
      print 'Output directory [./output]: '
      out_dir = gets&.strip
      out_dir = './output' if out_dir.nil? || out_dir.empty?

      print 'Client name: '
      client = gets&.strip
      @config[:client_name] = client unless client.empty?

      Dir.mkdir(out_dir) unless Dir.exist?(out_dir)

      # Ensure we have a design
      if @last_design.nil?
        live_preview
      end
      return unless @last_design

      # SketchUp script
      result = SketchupBuilder.write_script(@last_design, @last_panels, current_cfg,
                                            @config[:client_name], out_dir)
      puts "SketchUp script: #{result[:script]}"

      # Cutlist text
      cutlist = CutlistGenerator.generate(@last_panels)
      sheets = CutlistGenerator.nest(@last_panels)
      usage = CutlistGenerator.usage(sheets)
      report = CutlistGenerator.text_report(cutlist, sheets, usage, @last_design,
                                            current_cfg, @config[:client_name])
      cutlist_path = File.join(out_dir, "#{@config[:client_name].gsub(/[^a-zA-Z0-9_-]/, '_')}_cutlist.txt")
      File.write(cutlist_path, report)
      puts "Cutlist: #{cutlist_path}"

      # PDF
      begin
        pdf_path = PDFPlanGenerator.generate(@last_design, @last_panels, sheets, usage,
                                            current_cfg, @config[:client_name], out_dir)
        puts "PDF plan: #{pdf_path}"
      rescue StandardError => e
        puts "PDF generation failed: #{e.message}"
      end

      puts 'Done!'
    end

    # ---- Quick Calc (all-in-one live mode) ----

    def quick_calc
      puts '--- Quick Calc Mode ---'
      puts 'Enter parameters (type=w/h/d/vol/tuning). Type "done" to exit.'
      puts 'Example: type=ported w=36 h=18 d=18 vol=2.0 tune=32'

      loop do
        print 'qc> '
        input = gets&.strip
        break if input.nil? || input.downcase == 'done' || input.downcase == 'q'

        # Parse key=value pairs
        parts = input.split(/\s+/)
        parts.each do |part|
          next unless part =~ /=/
          key, val = part.split('=', 2)
          case key.downcase
          when 'type'
            val_sym = val.to_sym
            val_sym = :bandpass_4th if val_sym == :bandpass
            @config[:type] = val_sym if %i[sealed ported bandpass_4th].include?(val_sym)
          when 'w', 'width' then @config[:max_width] = val.to_f
          when 'h', 'height' then @config[:max_height] = val.to_f
          when 'd', 'depth' then @config[:max_depth] = val.to_f
          when 'vol' then @config[:target_volume] = val.to_f
          when 'tune' then @config[:tuning_frequency] = val.to_f
          when 'subs' then @config[:num_subs] = val.to_i
          when 'mt' then @config[:material_thickness] = val.to_f
          when 'pl'
            @config[:power_level] = val.to_sym if %i[daily sql spl].include?(val.to_sym)
          end
        end

        live_preview
      end
    end

    # ---- Helpers ----

    def prompt_f(label, default)
      print "#{label} [#{default}]: "
      val = gets&.strip
      val.nil? || val.empty? ? default : val.to_f
    end

    def prompt_i(label, default)
      print "#{label} [#{default}]: "
      val = gets&.strip
      val.nil? || val.empty? ? default : val.to_i
    end

    def prompt_y(label, default)
      print "#{label} [#{default ? 'Y/n' : 'y/N'}]: "
      val = gets&.strip&.downcase
      return default if val.nil? || val.empty?
      val == 'y' || val == 'yes'
    end

    # Format a value based on current units.
    def fmt(value, type)
      case type
      when :length
        Units.fmt_length(value, @config[:units] || :imperial)
      when :volume
        Units.fmt_volume(value, @config[:units] || :imperial)
      when :area
        Units.fmt_area(value, @config[:units] || :imperial)
      when :freq
        Units.freq(value)
      else
        value.to_s
      end
    end

    # Build an EnclosureConfig from the current @config hash.
    def current_cfg
      sub = SubwooferDB.find("#{@config[:sub_brand]} #{@config[:sub_model]}") ||
            SubwooferDB.default_for_size(@config[:sub_size])

      EnclosureConfig.new(
        type: @config[:type],
        target_volume: @config[:target_volume],
        tuning_frequency: @config[:tuning_frequency],
        num_subs: @config[:num_subs],
        sub_specs: [sub],
        max_width: @config[:max_width],
        max_height: @config[:max_height],
        max_depth: @config[:max_depth],
        material_thickness: @config[:material_thickness],
        double_baffle: @config[:double_baffle],
        extra_bracing: @config[:extra_bracing],
        separate_chambers: @config[:separate_chambers],
        power_level: @config[:power_level],
        bandpass_ratio: @config[:bandpass_ratio]
      )
    end
  end
end
