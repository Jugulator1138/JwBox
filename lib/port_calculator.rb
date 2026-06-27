module PortCalculator
  SPEED_OF_SOUND = 13504.0

  def self.port_length(tuning_freq, box_vol_cu_in, port_area_sq_in)
    return nil if tuning_freq <= 0 || box_vol_cu_in <= 0 || port_area_sq_in <= 0
    lp = (SPEED_OF_SOUND ** 2 * port_area_sq_in) / (4 * Math::PI ** 2 * tuning_freq ** 2 * box_vol_cu_in)
    end_correction = 0.825 * Math.sqrt(port_area_sq_in)
    actual = lp - end_correction
    [actual, 1.0].max
  end

  def self.tuning_frequency(box_vol_cu_in, port_area_sq_in, port_length)
    return nil if box_vol_cu_in <= 0 || port_area_sq_in <= 0 || port_length <= 0
    end_correction = 0.825 * Math.sqrt(port_area_sq_in)
    lp = port_length + end_correction
    (SPEED_OF_SOUND / (2 * Math::PI)) * Math.sqrt(port_area_sq_in / (box_vol_cu_in * lp))
  end

  def self.minimum_port_area(box_vol_cu_ft, power_level = :sql)
    multiplier = case power_level
                 when :daily then 12.0
                 when :sql   then 14.0
                 when :spl   then 18.0
                 else 14.0
    end
    box_vol_cu_ft * multiplier
  end

  def self.slot_port_dimensions(port_area, max_width, material_thickness = 0.75)
    usable_width = max_width - material_thickness - 0.5
    port_width = [usable_width, 3.0].max
    port_height = port_area / port_width
    if port_height < 2.0
      port_height = 2.0
      port_width = port_area / port_height
    elsif port_height > 6.0
      port_height = 6.0
      port_width = port_area / port_height
    end
    { width: port_width.round(3), height: port_height.round(3), area: (port_width * port_height).round(3) }
  end

  def self.design_slot_port(tuning_freq, net_vol_cu_in, int_width, int_depth, power_level = :sql, material_thickness = 0.75)
    net_vol_cuft = net_vol_cu_in / 1728.0
    min_area = minimum_port_area(net_vol_cuft, power_level)
    slot = slot_port_dimensions(min_area, int_width, material_thickness)
    length = port_length(tuning_freq, net_vol_cu_in, slot[:area])
    available_path = int_depth + int_width - slot[:width] - (material_thickness * 2)
    fits = length <= available_path
    path_type = length <= int_depth ? :straight : :l_shaped
    port_vol_cu_in = slot[:area] * length
    actual_tuning = tuning_frequency(net_vol_cu_in, slot[:area], length)

    {
      tuning_frequency: tuning_freq, actual_tuning: actual_tuning.round(1),
      port_width: slot[:width], port_height: slot[:height], port_area: slot[:area],
      port_length: length.round(3), port_vol_cu_in: port_vol_cu_in.round(2),
      port_vol_cu_ft: (port_vol_cu_in / 1728.0).round(4),
      path_type: path_type, fits_in_box: fits,
      available_path_length: available_path.round(2),
      material_thickness: material_thickness, power_level: power_level
    }
  end

  def self.port_displacement(port_spec)
    wall_vol = port_spec[:port_length] * port_spec[:port_height] * port_spec[:material_thickness]
    wall_vol / 1728.0
  end
end
