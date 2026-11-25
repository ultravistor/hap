# Trackpad Haptic Generator

A lightweight macOS GUI utility that continuously triggers haptic feedback on a MacBook's Force Touch trackpad (Taptic Engine) with customizable intervals, waveform patterns, and intensity using Apple's private `MultitouchSupport.framework`.

## Requirements
* macOS (Mac with a Force Touch trackpad)

## Quick Start (Pre-built Binary)

A code-signed binary (`hap`) is included, so you can run it immediately without compiling:

```bash
./hap
```

*(Note: If you download the binary directly via a browser, you may need to grant execution permission once with `chmod +x hap`.)*

## Usage

```bash
./hap [interval] [pattern_id] [intensity]
```

### Arguments (Optional)
1. **Interval (sec)**: Loop interval between pulses (Default: `0.1`, Min: `0.01`)
2. **Pattern ID**: Taptic Engine waveform pattern ID. (1 = Light, 2 = Strong Force, 3 = Mechanical Alignment, 4 = Subtle Tick) (Default: `1`)
3. **Intensity**: Vibration strength from `0.0` to `1.0` (Default: `1.0`)

### Examples

```bash
# Run with default settings
./hap

# Run with 0.05s interval, pattern ID 2, and 0.8 intensity
./hap 0.05 2 0.8
```

Closing the GUI window will terminate the application and stop the vibrations.

## Build from Source

If you prefer to compile it yourself (requires Xcode Command Line Tools):

```bash
clang -framework AppKit hap.m -o hap
```

## Disclaimer
* This tool relies on undocumented Apple private frameworks and may break in future macOS updates.
* Not suitable for App Store distribution.
