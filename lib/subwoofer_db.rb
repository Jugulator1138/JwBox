# frozen_string_literal: true

# SubwooferDB — database of known subwoofer specifications.
# Provides lookup, fuzzy matching, and default recommendations by size.
module SubwooferDB
  # Each entry: brand, model, size (in), cutout (in), depth (in),
  #              disp (cu ft), sealed (cu ft target), ported (cu ft target), tune (Hz)
  KNOWN = {
    'skar_vxf_12' => {
      brand: 'Skar', model: 'VXF-12', size: 12, cutout: 11.0, depth: 7.5,
      disp: 0.06, sealed: 1.25, ported: 2.0, tune: 32
    },
    'skar_vxf_10' => {
      brand: 'Skar', model: 'VXF-10', size: 10, cutout: 9.0, depth: 6.5,
      disp: 0.05, sealed: 0.75, ported: 1.25, tune: 34
    },
    'skar_evl_12' => {
      brand: 'Skar', model: 'EVL-12', size: 12, cutout: 11.0, depth: 8.0,
      disp: 0.08, sealed: 1.5, ported: 2.5, tune: 30
    },
    'skar_evl_10' => {
      brand: 'Skar', model: 'EVL-10', size: 10, cutout: 9.0, depth: 7.0,
      disp: 0.06, sealed: 1.0, ported: 1.5, tune: 32
    },
    'skar_sdr_12' => {
      brand: 'Skar', model: 'SDR-12', size: 12, cutout: 11.0, depth: 6.5,
      disp: 0.05, sealed: 1.0, ported: 1.5, tune: 34
    },
    'skar_sdr_10' => {
      brand: 'Skar', model: 'SDR-10', size: 10, cutout: 9.0, depth: 5.75,
      disp: 0.04, sealed: 0.63, ported: 1.0, tune: 36
    },
    'sundown_x12' => {
      brand: 'Sundown', model: 'X-12', size: 12, cutout: 11.0, depth: 7.5,
      disp: 0.07, sealed: 1.25, ported: 2.0, tune: 32
    },
    'sundown_x10' => {
      brand: 'Sundown', model: 'X-10', size: 10, cutout: 9.0, depth: 6.5,
      disp: 0.06, sealed: 0.75, ported: 1.25, tune: 34
    },
    'sundown_sa_12' => {
      brand: 'Sundown', model: 'SA-12', size: 12, cutout: 11.0, depth: 7.0,
      disp: 0.06, sealed: 1.0, ported: 1.5, tune: 34
    },
    'sundown_sa_10' => {
      brand: 'Sundown', model: 'SA-10', size: 10, cutout: 9.0, depth: 6.0,
      disp: 0.04, sealed: 0.63, ported: 1.0, tune: 36
    },
    'kicker_compr_12' => {
      brand: 'Kicker', model: 'CompR 12', size: 12, cutout: 11.0, depth: 6.5,
      disp: 0.05, sealed: 1.0, ported: 1.5, tune: 34
    },
    'kicker_compr_10' => {
      brand: 'Kicker', model: 'CompR 10', size: 10, cutout: 9.0, depth: 5.5,
      disp: 0.04, sealed: 0.63, ported: 1.0, tune: 36
    },
    'kicker_l7r_12' => {
      brand: 'Kicker', model: 'L7R 12', size: 12, cutout: 11.0, depth: 7.5,
      disp: 0.07, sealed: 1.25, ported: 2.0, tune: 32
    },
    'kicker_l7r_10' => {
      brand: 'Kicker', model: 'L7R 10', size: 10, cutout: 9.0, depth: 6.5,
      disp: 0.05, sealed: 0.75, ported: 1.25, tune: 34
    },
    'jl_12w6v3' => {
      brand: 'JL Audio', model: '12W6v3', size: 12, cutout: 11.0, depth: 7.5,
      disp: 0.07, sealed: 1.25, ported: 2.0, tune: 32
    },
    'jl_12w7' => {
      brand: 'JL Audio', model: '12W7', size: 12, cutout: 11.0, depth: 8.0,
      disp: 0.08, sealed: 1.5, ported: 2.5, tune: 30
    },
    'rockford_p3d4_12' => {
      brand: 'Rockford Fosgate', model: 'P3D4-12', size: 12, cutout: 11.0, depth: 7.0,
      disp: 0.06, sealed: 1.0, ported: 1.5, tune: 34
    },
    'rockford_t1d4_12' => {
      brand: 'Rockford Fosgate', model: 'T1D4-12', size: 12, cutout: 11.0, depth: 7.5,
      disp: 0.07, sealed: 1.25, ported: 2.0, tune: 32
    },
    'dc_level3_12' => {
      brand: 'DC Audio', model: 'Level 3 12', size: 12, cutout: 11.0, depth: 7.5,
      disp: 0.07, sealed: 1.25, ported: 2.0, tune: 32
    },
    'dc_level5_12' => {
      brand: 'DC Audio', model: 'Level 5 12', size: 12, cutout: 11.0, depth: 8.0,
      disp: 0.08, sealed: 1.5, ported: 2.5, tune: 30
    },
    'american_bass_xfl_12' => {
      brand: 'American Bass', model: 'XFL 12', size: 12, cutout: 11.0, depth: 7.5,
      disp: 0.07, sealed: 1.25, ported: 2.0, tune: 32
    },
    'american_bass_hd_12' => {
      brand: 'American Bass', model: 'HD 12', size: 12, cutout: 11.0, depth: 8.0,
      disp: 0.08, sealed: 1.5, ported: 2.5, tune: 30
    },
    'deaf_bonce_apocalypse_12' => {
      brand: 'Deaf Bonce', model: 'Apocalypse 12', size: 12, cutout: 11.0, depth: 8.5,
      disp: 0.09, sealed: 1.75, ported: 3.0, tune: 28
    },
    'taramps_pro_12' => {
      brand: 'Taramps', model: 'Pro 12', size: 12, cutout: 11.0, depth: 7.0,
      disp: 0.06, sealed: 1.0, ported: 1.5, tune: 34
    }
  }.freeze

  # Normalize a user input string to a lookup key.
  # @param input [String]
  # @return [String, nil]
  def self.normalize(input)
    return nil if input.nil? || input.strip.empty?

    key = input.strip.downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').gsub(/^_|_$/, '')
    key
  end

  # Find a subwoofer by key or fuzzy match on brand/model.
  # @param query [String]
  # @return [Hash, nil]
  def self.find(query)
    key = normalize(query)
    return KNOWN[key] if KNOWN.key?(key)

    # Fuzzy: try partial match
    q = query.strip.downcase
    KNOWN.each do |k, v|
      return v if k.include?(q) || v[:brand].downcase.include?(q) || v[:model].downcase.include?(q)
    end
    nil
  end

  # Return a default sub spec for a given size.
  # @param size [Integer] e.g. 12
  # @return [Hash]
  def self.default_for_size(size)
    KNOWN.values.find { |s| s[:size] == size } || {
      brand: 'Generic', model: "#{size}\"", size: size,
      cutout: size - 1.0, depth: 7.0, disp: 0.06,
      sealed: 1.0, ported: 1.5, tune: 34
    }
  end

  # Extract the numeric size from a string like "12W6v3" or "10 inch".
  # @param input [String]
  # @return [Integer, nil]
  def self.extract_size(input)
    return nil unless input

    m = input.to_s.match(/(\d+)/)
    m ? m[1].to_i : nil
  end

  # List all known subwoofers.
  # @return [Array<Hash>]
  def self.list_all
    KNOWN.values.sort_by { |s| [s[:brand], s[:size], s[:model]] }
  end
end
