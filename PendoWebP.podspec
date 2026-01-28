#
# PendoWebP.podspec
# Namespaced fork of Google's libwebp for internal Pendo projects
# Based on official libwebp 1.6.0 podspec structure
#

Pod::Spec.new do |s|
  s.name             = 'PendoWebP'
  s.version          = '1.6.0'
  s.summary          = 'Pendo-namespaced fork of Google libwebp'
  
  s.description      = <<-DESC
PendoWebP is a namespaced fork of Google's libwebp library (v1.6.0).
All public symbols are prefixed with PND to prevent dependency conflicts.

Based on: https://chromium.googlesource.com/webm/libwebp @ v1.6.0
                       DESC
  
  s.homepage         = 'https://github.com/pendo-io/iOSwebp'
  s.license          = { :type => 'BSD', :file => 'LICENSE' }
  s.author           = { 'Pendo' => 'dev@pendo.io' }
  s.source           = { 
    :git => 'https://github.com/pendo-io/iOSwebp.git', 
    :tag => "v#{s.version}-pendo" 
  }
  
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.13'
  
  s.module_name = 'PendoWebP'
  s.requires_arc = false
  
  # Match official libwebp configuration
  s.pod_target_xcconfig = {
    'USER_HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/PendoWebP/ ${PODS_TARGET_SRCROOT}/'
  }
  
  # This is CRITICAL for finding src/dsp/yuv.h from src/dsp/yuv_neon.c
  s.preserve_paths = 'src'
  
  # CRITICAL FIX: Change all absolute "src/..." includes to relative paths for CocoaPods
  s.prepare_command = <<-CMD
    echo "PendoWebP: Fixing include paths for CocoaPods compatibility..."
    
    # Fix all src/ subdirectory includes within src/ files (e.g., src/dsp/yuv.c includes src/dsp/yuv.h)
    find src -type f \\( -name "*.c" -o -name "*.h" \\) -exec sed -i '' \\
      -e 's|"src/dsp/|"|g' \\
      -e 's|"src/dec/|"../dec/|g' \\
      -e 's|"src/enc/|"../enc/|g' \\
      -e 's|"src/utils/|"../utils/|g' \\
      -e 's|"src/mux/|"../mux/|g' \\
      -e 's|"src/demux/|"../demux/|g' \\
      -e 's|"src/webp/|"../webp/|g' \\
      {} \\;
    
    # Fix sharpyuv includes
    find sharpyuv -type f \\( -name "*.c" -o -name "*.h" \\) -exec sed -i '' \\
      -e 's|"sharpyuv/|"|g' \\
      -e 's|"src/webp/|"../src/webp/|g' \\
      -e 's|"src/dsp/cpu.c"|"../src/dsp/cpu.c"|g' \\
      -e 's|"src/dsp/cpu.h"|"../src/dsp/cpu.h"|g' \\
      {} \\;
    
    # Remove config.h includes (not needed for CocoaPods)
    find . -type f \\( -name "*.c" -o -name "*.h" \\) -exec sed -i '' \\
      -e 's|#include ".*config.h"|// Removed config.h for CocoaPods|g' \\
      {} \\;
    
    echo "PendoWebP: Include paths fixed ✓"
  CMD
  
  # Use subspecs like official libwebp for proper header resolution
  s.default_subspecs = ['sharpyuv', 'webp', 'demux', 'mux']
  
  # SharpYUV subspec
  s.subspec 'sharpyuv' do |ss|
    ss.source_files = 'sharpyuv/*.{h,c}'
    ss.public_header_files = 'sharpyuv/sharpyuv.h'
  end
  
  # Core WebP subspec
  s.subspec 'webp' do |ss|
    ss.dependency 'PendoWebP/sharpyuv'
    
    ss.source_files = [
      'src/webp/decode.h',
      'src/webp/encode.h',
      'src/webp/types.h',
      'src/webp/mux_types.h',
      'src/webp/format_constants.h',
      'src/utils/*.{h,c}',
      'src/dsp/*.{h,c}',
      'src/dec/*.{h,c}',
      'src/enc/*.{h,c}'
    ]
    
    ss.public_header_files = [
      'src/webp/decode.h',
      'src/webp/encode.h',
      'src/webp/types.h',
      'src/webp/mux_types.h',
      'src/webp/format_constants.h'
    ]
    
    # Force correct header path at subspec level
    ss.xcconfig = {
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
      'USER_HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
    }
  end
  
  # Demux subspec
  s.subspec 'demux' do |ss|
    ss.dependency 'PendoWebP/webp'
    
    ss.source_files = [
      'src/demux/*.{h,c}',
      'src/webp/demux.h'
    ]
    
    ss.public_header_files = 'src/webp/demux.h'
  end
  
  # Mux subspec
  s.subspec 'mux' do |ss|
    ss.dependency 'PendoWebP/demux'
    
    ss.source_files = [
      'src/mux/*.{h,c}',
      'src/webp/mux.h'
    ]
    
    ss.public_header_files = 'src/webp/mux.h'
  end
  
  # Compiler flags (removed HAVE_CONFIG_H since we don't generate config.h)
  s.compiler_flags = '-DWEBP_USE_THREAD'
  s.frameworks = 'Foundation', 'CoreGraphics', 'Accelerate'
  s.libraries = 'c++'
end
