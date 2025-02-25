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
    'OTHER_SWIFT_FLAGS' => '-DCocoaPods'
  }

  spec.default_subspecs = 'WalletKit'

  spec.subspec 'WalletKit' do |ss|
    ss.source_files = 'Sources/ReownWalletKit/**/*.{h,m,swift}'
    ss.dependency 'YttriumWrapper', '0.8.34'
    ss.dependency 'reown-swift/WalletConnectSign'
    ss.dependency 'reown-swift/WalletConnectPush'
    ss.dependency 'reown-swift/WalletConnectVerify'
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
    ss.dependency 'YttriumWrapper', '0.8.34'
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
