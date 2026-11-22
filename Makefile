PROJECT := DailyKeep.xcodeproj
SCHEME  := DailyKeep
DEVICE  ?= iPhone 17 Pro
DERIVED := build
BUNDLE   = $(shell awk -F'= *' '/^DK_BUNDLE_ID/{print $$2}' Config/Env.xcconfig)
TEAM     = $(shell awk -F'= *' '/^DEVELOPMENT_TEAM/{print $$2}' Config/Env.xcconfig)
# Team ID가 비어 있으면 맥은 iCloud 없이 로컬 서명한다(iOS 시뮬레이터는 그대로 빌드됨)
ifeq ($(strip $(TEAM)),)
  MAC_SIGN := CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=Resources/DailyKeep-macOS-local.entitlements
endif
MAC_APP := $(DERIVED)/Build/Products/Debug/DailyKeep.app
IOS_APP := $(DERIVED)/Build/Products/Debug-iphonesimulator/DailyKeep.app

.PHONY: env generate build-ios build-mac build run mac test clean

# Env.xcconfig가 없으면 예시 파일로 만든다
env:
	@test -f Config/Env.xcconfig || { cp Config/Env.example.xcconfig Config/Env.xcconfig; echo "Config/Env.xcconfig 생성됨 — 값을 채워주세요"; }

# 소스 파일 추가/삭제 시 xcodeproj 재생성
generate: env
	xcodegen generate --quiet

# DEVICE="iPhone 17 Pro Max" make build-ios 처럼 시뮬레이터를 바꿀 수 있다
build-ios: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=iOS Simulator,name=$(DEVICE)' \
		-derivedDataPath $(DERIVED) -quiet build

build-mac: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) -quiet build $(MAC_SIGN)

build: build-ios build-mac

# iOS 시뮬레이터에서 실행
run: build-ios
	xcrun simctl boot "$(DEVICE)" 2>/dev/null || true
	xcrun simctl install "$(DEVICE)" $(IOS_APP)
	xcrun simctl launch "$(DEVICE)" $(BUNDLE)

# 맥 앱 실행
mac: build-mac
	open $(MAC_APP)

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' \
		-derivedDataPath $(DERIVED) -quiet test $(MAC_SIGN)

clean:
	rm -rf $(DERIVED)
