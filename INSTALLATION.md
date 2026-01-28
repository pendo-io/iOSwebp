# PendoWebP Installation Guide

## Installation

Add to your `Podfile`:

```ruby
pod 'PendoWebP', :git => 'https://github.com/orendayan/pendowebp.git', :tag => 'v1.6.0-pendo'
```

## ⚠️ REQUIRED: Podfile post_install Hook

**PendoWebP requires a post_install hook** to fix include paths. Add this to your `Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Your other post_install code...
    
    # REQUIRED for PendoWebP
    if target.name == 'PendoWebP'
      puts 'Fixing PendoWebP include paths...'
      
      Dir.glob('Pods/PendoWebP/**/*.{c,h}') do |file|
        next if file.include?('backup')
        
        content = File.read(file)
        
        if file.include?('sharpyuv/')
          # For sharpyuv files
          modified = content
            .gsub('#include "src/dsp/cpu.c"', '#include "../src/dsp/cpu.c"')
            .gsub('#include "src/dsp/cpu.h"', '#include "../src/dsp/cpu.h"')
            .gsub('"src/webp/', '"../src/webp/')
            .gsub('"sharpyuv/', '"')
            .gsub(/"[\.\/]*config\.h"/, '/* config.h */')
        else
          # For src/ files
          modified = content
            .gsub('"src/dsp/', '"')
            .gsub('"src/dec/', '"../dec/')
            .gsub('"src/enc/', '"../enc/')
            .gsub('"src/utils/', '"../utils/')
            .gsub('"src/mux/', '"../mux/')
            .gsub('"src/demux/', '"../demux/')
            .gsub('"src/webp/', '"../webp/')
            .gsub('"sharpyuv/', '"../../sharpyuv/')
            .gsub('#include "../webp/config.h"', '// config.h removed')
            .gsub(/"[\.\/]*config\.h"/, '/* config.h */')
        end
        
        File.write(file, modified) if content != modified
      end
      
      puts 'PendoWebP: Include paths fixed'
    end
  end
end
```

## Why Is This Needed?

PendoWebP's C source files use absolute includes like:
```c
#include "src/dsp/yuv.h"
```

CocoaPods builds each pod in isolation, so these paths don't work. The hook converts them to relative paths.

## Usage

```objective-c
#import <webp/encode.h>

uint8_t *output;
size_t size = PNDWebPEncodeRGBA(pixels, width, height, stride, quality, &output);
// Use WebP data...
PNDWebPFree(output);
```

## Verification

After `pod install`, you should see:
```
Fixing PendoWebP include paths...
PendoWebP: Include paths fixed
```

## Troubleshooting

### Build fails with "file not found" errors

Make sure the post_install hook is in your Podfile and runs successfully.

### Hook doesn't run

Check that the hook is inside the `post_install do |installer|` block and before the final `end`.


