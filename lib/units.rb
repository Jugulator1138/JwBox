# JwBox Unit Conversion Module
module Units
  IN_PER_CM = 2.54
  CUIN_PER_CCM = 0.0610237
  CUFT_PER_CUM = 0.0000353147

  def self.imperial?; @system == :imperial; end
  def self.metric?; @system == :metric; end
  def self.set_system(s); @system = s; end
  def self.system_label; imperial? ? "Imperial (in)" : "Metric (cm)"; end
  def self.to_cm(inches); inches * IN_PER_CM; end
  def self.to_inches(cm); cm / IN_PER_CM; end

  def self.fmt_length(val, units = nil)
    units ||= @system
    return "" if val.nil?
    units == :imperial ? "#{val.round(3)}\"" : "#{(val * IN_PER_CM).round(2)} cm"
  end

  def self.fmt_volume(val, units = nil)
    units ||= @system
    return "" if val.nil?
    units == :imperial ? "#{val.round(3)} ft³" : "#{(val / CUFT_PER_CUM).round(1)} L"
  end

  def self.fmt_area(val, units = nil)
    units ||= @system
    return "" if val.nil?
    units == :imperial ? "#{val.round(1)} in²" : "#{(val * IN_PER_CM * IN_PER_CM).round(1)} cm²"
  end

  def self.freq(val)
    return "" if val.nil?
    "#{val.round(1)} Hz"
  end

  def self.fmt_freq(val); freq(val); end

  def self.input_to_inches(val)
    return nil if val.nil? || val.to_f <= 0
    imperial? ? val.to_f : to_inches(val.to_f)
  end

  def self.input_to_cu_ft(val)
    return nil if val.nil? || val.to_f <= 0
    imperial? ? val.to_f : (val.to_f * CUFT_PER_CUM)
  end
end

Units.set_system(:imperial)
