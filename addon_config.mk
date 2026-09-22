meta:
	ADDON_NAME = ofxtvOSBoost
	ADDON_DESCRIPTION = Boost 1.92.0 C++20 XCFramework for tvOS.
	ADDON_AUTHOR = Danoli3
	ADDON_TAGS = "tvos" "boost"
	ADDON_URL = https://github.com/danoli3/ofxtvOSBoost
common:
	ADDON_INCLUDES = libs/boost/tvos/boost.xcframework/tvos-arm64/Headers
	ADDON_SOURCES_EXCLUDE = libs/boost/include/%
	ADDON_LIBS_EXCLUDE = libs/boost/tvos/libboost.a
tvos:
	ADDON_FRAMEWORKS = libs/boost/tvos/boost.xcframework
