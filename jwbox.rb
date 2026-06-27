# frozen_string_literal: true

# JwBox — Advanced Subwoofer Enclosure Calculator
# Terminal TUI with live real-time calculation, imperial/metric support,
# sealed/ported/4th-order bandpass design, cut-list nesting, PDF plans,
# and SketchUp .rb script output.

require 'fileutils'
require 'json'
require 'time'

require_relative 'lib/units'
require_relative 'lib/enclosure_calculator'
require_relative 'lib/port_calculator'
require_relative 'lib/cutlist_generator'
require_relative 'lib/sketchup_builder'
require_relative 'lib/subwoofer_db'

module JwBox
  VERSION = '1.0.0'

  def self.run
    TUI.new.start
  end
end

require_relative 'lib/tui'
