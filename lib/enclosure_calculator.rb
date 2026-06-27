# frozen_string_literal: true

require_relative 'port_calculator'

# EnclosureConfig — parameters that describe a build.
EnclosureConfig = Struct.new(
  :type,              # :sealed, :ported, :bandpass_4th
  :target_volume,     # cubic feet (per sub for multi-sub)
  :tuning_frequency,  # Hz (ported / bandpass)
  :num_subs,          # Integer
  :sub_specs,         # Array of hashes: { size:, cutout:, depth:, disp:, sealed:, ported:, tune: }
  :max_width,         # inches
  :max_height,        # inches
  :max_depth,         # inches
  :material_thickness,# inches (typically 0.75)
  :double_baffle,     # true/false
  :extra_bracing,     # true/false
  :separate_chambers, # true/false (bandpass)
  :power_level,       # :daily, :sql, :spl
  :bandpass_ratio,    # Float (sealed / total for 4th order)
  keyword_init: true
) do
  def to_h
    super.transform_keys(&:to_s)
  end
end

# Panel — a single piece of material to cut.
Panel = Struct.new(
  :name,              # String label
  :width,             # inches
  :height,            # inches
  :quantity,          # Integer
  :has_cutout,       # true/false
  :cutout_diameter,   # inches
  :cutout_offset_x,   # inches from left
  :cutout_offset_y,   # inches from bottom
  :notes,             # String
  keyword_init: true
) do
  def area_sq_in
    (width * height).round(2)
  end
end

# EnclosureCalculator — core math engine for designing subwoofer enclosures.
# Supports sealed, ported, and 4th-order bandpass topologies. Operates entirely
# in imperial units (inches / cubic feet); the TUI layer handles unit conversion.
module EnclosureCalculator
  DEFAULT_THICKNESS = 0.75  # 3/4" MDF

  # ─── Volume helpers ──────────────────────────────────────────────

  def self.internal_volume(width, height, depth, thickness = DEFAULT_THICKNESS)
    [(width - 2 * thickness), (height - 2 * thickness), (depth - 2 * thickness)].reduce(:*) || 0
  end

  def self.internal_dimensions(width, height, depth, thickness = DEFAULT_THICKNESS)
    { width: width - 2 * thickness, height: height - 2 * thickness, depth: depth - 2 * thickness }
  end

  def self.to_cubic_feet(cu_in)
    cu_in / 1728.0
  end

  def self.to_cubic_inches(cu_ft)
    cu_ft * 1728.0
  end

  # ─── Displacement calculations ───────────────────────────────────

  def self.bracing_displacement(int_w, int_h, thickness = DEFAULT_THICKNESS, window_pct = 0.6)
    frame_area = int_w * int_h
    window_area = (int_w * window_pct) * (int_h * window_pct)
    frame_volume = (frame_area - window_area) * thickness
    corner_leg = (1 - window_pct) / 2
    corner_area = 4 * (0.5 * (int_w * corner_leg) * (int_h * corner_leg))
    frame_volume + corner_area * thickness
  end

  def self.double_baffle_displacement(baffle_w, baffle_h, thickness = DEFAULT_THICKNESS, cutout_d = 0, num_cutouts = 1)
    cutout_area = num_cutouts * (Math::PI * (cutout_d / 2.0) ** 2)
    (baffle_w * baffle_h - cutout_area) * thickness
  end

  def self.terminal_cup_displacement
    3.0 * 3.0 * 1.5
  end

  # ─── Net volume ──────────────────────────────────────────────────

  def self.net_volume(config)
    int = internal_dimensions(config.max_width, config.max_height, config.max_depth, config.material_thickness)
    gross = int[:width] * int[:height] * int[:depth]
    disp = 0.0

    # Sum displacement from all subwofer(s)
    Array(config.sub_specs).each do |sub|
      next unless sub
      disp += (sub[:disp] || sub[:displacement] || 0) * 1728 * config.num_subs
    end

    if config.double_baffle
      cutout_d = (config.sub_specs&.first || {})[:cutout] || (config.sub_specs&.first || {})[:cutout_diameter] || 10.875
      disp += double_baffle_displacement(int[:width], int[:height], config.material_thickness, cutout_d, config.num_subs)
    end

    disp += bracing_displacement(int[:width], int[:height], config.material_thickness) if config.extra_bracing
    disp += terminal_cup_displacement

    gross - disp
  end

  # ─── Design: Sealed ──────────────────────────────────────────────

  def self.design_sealed(config)
    int_dims = internal_dimensions(config.max_width, config.max_height, config.max_depth, config.material_thickness)
    actual_net = net_volume(config)
    actual_cu_ft = to_cubic_feet(actual_net)
    per_sub = config.separate_chambers ? actual_cu_ft / [config.num_subs, 1].max : actual_cu_ft
    fits = per_sub >= config.target_volume * 0.95

    {
      enclosure_type: :sealed,
      external: { width: config.max_width, height: config.max_height, depth: config.max_depth },
      internal: int_dims,
      gross_volume_cu_ft: to_cubic_feet(int_dims[:width] * int_dims[:height] * int_dims[:depth]).round(3),
      net_volume_cu_ft: actual_cu_ft.round(3),
      per_sub_cu_ft: per_sub.round(3),
      target_cu_ft: config.target_volume,
      meets_target: fits,
      num_subs: config.num_subs,
      double_baffle: config.double_baffle,
      extra_bracing: config.extra_bracing,
      thickness: config.material_thickness,
      panels: generate_panels(:sealed, config, int_dims)
    }
  end

  # ─── Design: Ported ──────────────────────────────────────────────

  def self.design_ported(config)
    sealed = design_sealed(config)
    int_dims = sealed[:internal]

    port = PortCalculator.design_slot_port(
      config.tuning_frequency, sealed[:net_volume_cu_in] || to_cubic_inches(sealed[:net_volume_cu_ft]),
      int_dims[:width], int_dims[:depth], config.power_level, config.material_thickness
    )

    port_wall_disp = PortCalculator.port_displacement(port)
    adjusted_net = to_cubic_inches(sealed[:net_volume_cu_ft]) - (port_wall_disp * 1728)

    port = PortCalculator.design_slot_port(
      config.tuning_frequency, adjusted_net,
      int_dims[:width], int_dims[:depth], config.power_level, config.material_thickness
    )

    {
      enclosure_type: :ported,
      external: sealed[:external],
      internal: int_dims,
      gross_volume_cu_ft: sealed[:gross_volume_cu_ft],
      net_volume_cu_ft: to_cubic_feet(adjusted_net).round(3),
      per_sub_cu_ft: (to_cubic_feet(adjusted_net) / config.num_subs).round(3),
      target_cu_ft: config.target_volume,
      tuning_hz: config.tuning_frequency,
      actual_tuning_hz: port[:actual_tuning],
      port: port,
      num_subs: config.num_subs,
      double_baffle: config.double_baffle,
      extra_bracing: config.extra_bracing,
      thickness: config.material_thickness,
      panels: generate_panels(:ported, config, int_dims, port: port)
    }
  end

  # ─── Design: 4th Order Bandpass ──────────────────────────────────

  def self.design_bandpass_4th(config)
    ratio = config.bandpass_ratio || 0.6
    # ratio is ported/total; sealed = 1 - ratio
    sealed_ratio = 1.0 - ratio
    ported_ratio = ratio

    int_dims = internal_dimensions(config.max_width, config.max_height, config.max_depth, config.material_thickness)
    total_vol = internal_volume(config.max_width, config.max_height, config.max_depth, config.material_thickness)
    divider_vol = int_dims[:width] * int_dims[:height] * config.material_thickness
    usable = total_vol - divider_vol

    sealed_vol = usable * sealed_ratio
    ported_vol = usable * ported_ratio
    sealed_depth = sealed_vol / (int_dims[:width] * int_dims[:height])
    ported_depth = ported_vol / (int_dims[:width] * int_dims[:height])

    sub_disp = 0
    Array(config.sub_specs).each { |sub| sub_disp += (sub[:disp] || sub[:displacement] || 0) * 1728 * config.num_subs }
    sealed_net = sealed_vol - sub_disp

    port = PortCalculator.design_slot_port(
      config.tuning_frequency, ported_vol, int_dims[:width], ported_depth,
      config.power_level, config.material_thickness
    )
    port_wall_disp = PortCalculator.port_displacement(port) * 1728
    ported_net = ported_vol - port_wall_disp

    {
      enclosure_type: :bandpass_4th,
      external: { width: config.max_width, height: config.max_height, depth: config.max_depth },
      internal: int_dims,
      bandpass_ratio: config.bandpass_ratio,
      sealed_chamber: {
        gross_cu_in: sealed_vol, net_cu_in: sealed_net,
        net_cu_ft: to_cubic_feet(sealed_net).round(3), depth: sealed_depth.round(3)
      },
      ported_chamber: {
        gross_cu_in: ported_vol, net_cu_in: ported_net,
        net_cu_ft: to_cubic_feet(ported_net).round(3), depth: ported_depth.round(3), port: port
      },
      divider_position: sealed_depth + config.material_thickness,
      tuning_hz: config.tuning_frequency,
      actual_tuning_hz: port[:actual_tuning],
      num_subs: config.num_subs,
      double_baffle: config.double_baffle,
      extra_bracing: config.extra_bracing,
      thickness: config.material_thickness,
      panels: generate_panels(:bandpass_4th, config, int_dims, port: port)
    }
  end

  # ─── Main design entry point ─────────────────────────────────────

  def self.design(config)
    case config.type
    when :sealed          then design_sealed(config)
    when :ported          then design_ported(config)
    when :bandpass_4th    then design_bandpass_4th(config)
    else raise ArgumentError, "Unknown enclosure type: #{config.type}"
    end
  end

  # ─── Generate panel list ─────────────────────────────────────────

  def self.generate_panels(type, config, int_dims, port: nil)
    panels = []
    t = config.material_thickness
    ext = { width: config.max_width, height: config.max_height, depth: config.max_depth }

    sub = config.sub_specs&.first || {}
    cutout_d = sub[:cutout] || sub[:cutout_diameter] || 10.875

    case type
    when :sealed, :ported
      panels << Panel.new(name: "Front Baffle", width: ext[:width], height: ext[:height],
        quantity: config.double_baffle ? 2 : 1, has_cutout: true,
        cutout_diameter: cutout_d, cutout_offset_x: ext[:width] / 2.0, cutout_offset_y: ext[:height] / 2.0,
        notes: config.double_baffle ? "Double baffle — cut 2 identical pieces" : nil)

      panels << Panel.new(name: "Back Panel", width: ext[:width], height: ext[:height],
        quantity: 1, has_cutout: true, cutout_diameter: 3.0,
        cutout_offset_x: ext[:width] / 2.0, cutout_offset_y: ext[:height] - 3.0,
        notes: "Terminal cup cutout")

      panels << Panel.new(name: "Top Panel", width: ext[:width], height: ext[:depth] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)
      panels << Panel.new(name: "Bottom Panel", width: ext[:width], height: ext[:depth] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)
      panels << Panel.new(name: "Left Side", width: ext[:depth], height: ext[:height] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)
      panels << Panel.new(name: "Right Side", width: ext[:depth], height: ext[:height] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)

      if type == :ported && port
        panels << Panel.new(name: "Port Wall", width: port[:port_length], height: port[:port_height],
          quantity: 1, has_cutout: false, notes: "Slot port divider")
        if port[:path_type] == :l_shaped
          panels << Panel.new(name: "Port End Cap", width: port[:port_width] + t, height: port[:port_height],
            quantity: 1, has_cutout: false, notes: "Closes port at turn")
        end
      end

      if config.extra_bracing
        panels << Panel.new(name: "Window Brace", width: int_dims[:width], height: int_dims[:height],
          quantity: 1, has_cutout: true, cutout_diameter: [int_dims[:width], int_dims[:height]].min * 0.6,
          cutout_offset_x: int_dims[:width] / 2.0, cutout_offset_y: int_dims[:height] / 2.0,
          notes: "Window brace with 45° corner blocks")
      end

      if config.separate_chambers && config.num_subs > 1
        panels << Panel.new(name: "Chamber Divider", width: ext[:depth] - 2 * t, height: ext[:height] - 2 * t,
          quantity: config.num_subs - 1, has_cutout: false, notes: "Divides chambers for each subwoofer")
      end

    when :bandpass_4th
      panels << Panel.new(name: "Front Panel (Sealed)", width: ext[:width], height: ext[:height],
        quantity: 1, has_cutout: false, notes: "Sealed chamber front — no cutouts")

      panels << Panel.new(name: "Back Panel (Ported)", width: ext[:width], height: ext[:height],
        quantity: 1, has_cutout: true, cutout_diameter: nil, notes: "Port exit opening")

      panels << Panel.new(name: "Chamber Divider", width: ext[:width] - 2 * t, height: ext[:height] - 2 * t,
        quantity: config.double_baffle ? 2 : 1, has_cutout: true,
        cutout_diameter: cutout_d, cutout_offset_x: (ext[:width] - 2 * t) / 2.0,
        cutout_offset_y: (ext[:height] - 2 * t) / 2.0,
        notes: "Sub mounts here, fires into ported chamber")

      panels << Panel.new(name: "Top Panel", width: ext[:width], height: ext[:depth] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)
      panels << Panel.new(name: "Bottom Panel", width: ext[:width], height: ext[:depth] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)
      panels << Panel.new(name: "Left Side", width: ext[:depth], height: ext[:height] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)
      panels << Panel.new(name: "Right Side", width: ext[:depth], height: ext[:height] - 2 * t,
        quantity: 1, has_cutout: false, notes: nil)

      if port
        panels << Panel.new(name: "Port Wall", width: port[:port_length], height: port[:port_height],
          quantity: 1, has_cutout: false, notes: "Ported chamber slot port")
      end
    end

    panels
  end
end
