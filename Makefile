ARCHS = armv7 armv7s arm64
TARGET = iphone:clang:latest:latest
THEOS_BUILD_DIR = debs

include $(THEOS)/makefiles/common.mk

SOURCE_FILES=$(wildcard tweak/*.m tweak/*.mm tweak/*.x tweak/*.xm)

TWEAK_NAME = Consolidation
Consolidation_FILES = $(SOURCE_FILES)
Consolidation_FRAMEWORKS = UIKit CoreFoundation CoreGraphics CoreTelephony QuartzCore AudioToolbox
Consolidation_PRIVATE_FRAMEWORKS = BulletinBoard
Consolidation_LIBRARIES = applist
Consolidation_LDFLAGS += -lCSPreferencesProvider
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
	# install.exec "killall -9 Preferences"