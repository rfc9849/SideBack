PROJECT = SideBack.xcodeproj
SCHEME = SideBack
DERIVED_DATA = build
DESTINATION = platform=macOS,arch=$(shell uname -m)
SIGNING = CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual

.PHONY: generate build test run release

generate:
	xcodegen generate

build:
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) $(SIGNING) build

test:
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) $(SIGNING) test -parallel-testing-enabled NO

run: build
	open $(DERIVED_DATA)/Build/Products/Debug/SideBack.app

release:
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=macOS' -derivedDataPath $(DERIVED_DATA) $(SIGNING) ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
