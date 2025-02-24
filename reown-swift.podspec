require "json"

package = JSON.parse(File.read(File.join(__dir__, "Sources/WalletConnectRelay/PackageConfig.json")))

Pod::Spec.new do |spec|

  spec.name        = "reown-swift"
  spec.version     = package["version"]
  spec.summary     = "Reown Swift WalletKit & AppKit"
  spec.description = "Implementation of WalletKit and AppKit"
  spec.homepage    = "https://reown.com"
  spec.license     = { :type => 'Apache-2.0', :file => 'LICENSE' }
  spec.authors          = "Reown, Inc."
  spec.source = {
    :git => 'https://github.com/reown-com/reown-swift.git',
    :tag => spec.version.to_s
  }

  spec.platform     = :ios, '13.0'
  spec.swift_versions = '5.9'
spec.pod_target_xcconfig = {
  'OTHER_SWIFT_FLAGS' => '-DCocoaPods',
  'HEADER_SEARCH_PATHS' => [
    '${PODS_ROOT}/YttriumWrapper/platforms/swift/target/ios/libuniffi_yttrium.xcframework/ios-arm64/Headers/yttriumFFI',
    '${PODS_ROOT}/YttriumWrapper/platforms/swift/target/ios/libuniffi_yttrium.xcframework/ios-arm64_x86_64-simulator/Headers/yttriumFFI'
  ],
  'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/YttriumWrapper/platforms/swift/target/ios/',
  'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  'OTHER_LDFLAGS' => '-framework YttriumWrapper'
}


spec.prepare_command = <<-SCRIPT
  # Find and remove duplicate module maps in the YttriumWrapper
  # This script will be run after YttriumWrapper is installed but before reown-swift is built

  DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
  FRAMEWORK_INTERMEDIATES_DIR=$(find "$DERIVED_DATA_DIR" -path "*/Build/Products/*/XCFrameworkIntermediates/YttriumWrapper" 2>/dev/null)

  if [ -n "$FRAMEWORK_INTERMEDIATES_DIR" ]; then
    echo "Found YttriumWrapper intermediates at: $FRAMEWORK_INTERMEDIATES_DIR"

    # Find duplicate module maps and keep only one
    if [ -f "$FRAMEWORK_INTERMEDIATES_DIR/Headers/yttriumFFI/module.modulemap" ] && [ -f "$FRAMEWORK_INTERMEDIATES_DIR/Headers/module.modulemap" ]; then
      echo "Found duplicate module maps. Removing one..."
      rm -f "$FRAMEWORK_INTERMEDIATES_DIR/Headers/yttriumFFI/module.modulemap"
      echo "Removed duplicate module map at: $FRAMEWORK_INTERMEDIATES_DIR/Headers/yttriumFFI/module.modulemap"
    fi
  else
    echo "YttriumWrapper intermediates not found in DerivedData."
  fi
SCRIPT





  spec.default_subspecs = 'WalletKit'

    spec.dependency 'YttriumWrapper', '0.8.32'  # Move to root level


  spec.subspec 'WalletKit' do |ss|
    ss.source_files = 'Sources/ReownWalletKit/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectSign'
    ss.dependency 'reown-swift/WalletConnectPush'
    ss.dependency 'reown-swift/WalletConnectVerify'
      ss.xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/YttriumWrapper/platforms/swift/target/ios/'
  }
    end


  spec.subspec 'WalletConnectSign' do |ss|
    ss.source_files = 'Sources/WalletConnectSign/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectPairing'
    ss.dependency 'reown-swift/WalletConnectSigner'
    ss.dependency 'reown-swift/WalletConnectVerify'
    ss.dependency 'reown-swift/Events'
  end

  spec.subspec 'WalletConnectVerify' do |ss|
    ss.source_files = 'Sources/WalletConnectVerify/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectUtils'
    ss.dependency 'reown-swift/WalletConnectNetworking'
  end

  spec.subspec 'WalletConnectSigner' do |ss|
    ss.source_files = 'Sources/WalletConnectSigner/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectNetworking'
      ss.xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(PODS_ROOT)/YttriumWrapper/platforms/swift/target/ios/'
  }
  end

  spec.subspec 'WalletConnectIdentity' do |ss|
    ss.source_files = 'Sources/WalletConnectIdentity/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectNetworking'
    ss.dependency 'reown-swift/WalletConnectJWT'
  end

  spec.subspec 'WalletConnectPush' do |ss|
    ss.source_files = 'Sources/WalletConnectPush/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectNetworking'
    ss.dependency 'reown-swift/WalletConnectJWT'
  end

  spec.subspec 'WalletConnectJWT' do |ss|
    ss.source_files = 'Sources/WalletConnectJWT/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectKMS'
  end

  spec.subspec 'WalletConnectNetworking' do |ss|
    ss.source_files = 'Sources/WalletConnectNetworking/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectRelay'
    ss.dependency 'reown-swift/HTTPClient'
  end

  spec.subspec 'WalletConnectPairing' do |ss|
    ss.source_files = 'Sources/WalletConnectPairing/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectNetworking'
    ss.dependency 'reown-swift/Events'
  end

  spec.subspec 'ReownRouter' do |ss|
    ss.source_files = 'Sources/ReownRouter/**/*.{h,m,swift}'
    ss.platform = :ios
  end

  spec.subspec 'WalletConnectRelay' do |ss|
    ss.source_files = 'Sources/WalletConnectRelay/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectJWT'
    ss.resource_bundles = {
      'reown_WalletConnectRelay' => [
         'Sources/WalletConnectRelay/PackageConfig.json'
      ]
    }
  end

  spec.subspec 'WalletConnectUtils' do |ss|
    ss.source_files = 'Sources/WalletConnectUtils/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/JSONRPC'
  end

  spec.subspec 'WalletConnectKMS' do |ss|
    ss.source_files = 'Sources/WalletConnectKMS/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectUtils'
  end

  spec.subspec 'Commons' do |ss|
    ss.source_files = 'Sources/Commons/**/*.{h,m,swift}'
  end

  spec.subspec 'Events' do |ss|
    ss.source_files = 'Sources/Events/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/WalletConnectNetworking'
    ss.dependency 'reown-swift/WalletConnectUtils'
  end

  spec.subspec 'JSONRPC' do |ss|
    ss.source_files = 'Sources/JSONRPC/**/*.{h,m,swift}'
    ss.dependency 'reown-swift/Commons'
  end

  spec.subspec 'HTTPClient' do |ss|
    ss.source_files = 'Sources/HTTPClient/**/*.{h,m,swift}'
  end

end
