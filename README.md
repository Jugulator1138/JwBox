# JwBox — Subwoofer Enclosure Calculator

A terminal TUI tool for designing sealed, ported, and 4th-order bandpass
subwoofer enclosures with live real-time calculations, imperial/metric
support, cut-list nesting, PDF plans, and SketchUp `.rb` script output.

## Requirements

- Ruby >= 2.7
- Bundler

## Installation

```bash
cd E:\ClaudeCode\JwBox
bundle install
```

## Usage

### Interactive TUI (default)

```bash
ruby run.rb
# or
ruby jwbox.rb
```

Menu options:
1. **Dimensions** — set max outer width/height/depth and material thickness.
2. **Subwoofer** — pick driver from built-in database; set quantity.
3. **Build Prefs** — enclosure type, target volume, tuning, power level, etc.
4. **Units** — toggle Imperial (in) / Metric (cm).
5. **Show Results** — print full panel list and design summary.
6. **Generate** — produce SketchUp `.rb` script, cutlist text, and PDF plan.
7. **Quick Calc** — all-in-one live mode with instant numeric results.
Q. **Quit**

### Programmatic API

```ruby
require 'jwbox'

result = JwBox.calculate(
  type: :ported,
  width: 36, height: 18, depth: 18,
  material_thickness: 0.75,
  num_subs: 2, sub_size: 12,
  target_volume: 4.0,
  tuning_frequency: 32,
  power_level: :sql,
  units: :imperial
)
puts result[:design][:net_volume_cu_ft]
```

### Commands (Quick Calc mode)

```
type=ported w=36 h=18 d=18 vol=4.0 tune=32
```

## File Layout

```
JwBox/
├── jwbox.rb                  # Main entry point & module
├── run.rb                    # Shortcut runner
├── Gemfile                   # Dependencies
├── README.md                 # This file
└── lib/
    ├── units.rb              # Unit conversion helpers
    ├── port_calculator.rb    # Helmholtz port/slot math
    ├── enclosure_calculator.rb  # Core design engine
    ├── cutlist_generator.rb  # Cut-list & nesting
    ├── sketchup_builder.rb   # SketchUp .rb script output
    ├── subwoofer_db.rb       # Known subwoofer specs
    ├── pdf_plan_generator.rb # 6-page PDF plan
    └── tui.rb                # Terminal UI
```

## License

MIT
