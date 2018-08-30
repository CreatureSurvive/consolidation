ARCHS = armv7 armv7s arm64
TARGET = iphone:clang:11.2:10.0
THEOS_BUILD_DIR = debs

# THEOS_DEVICE_IP = 192.168.86.153
# THEOS_DEVICE_PORT = 22

GO_EASY_ON_ME = 1
FINALPACKAGE = 1
DEBUG = 0

include $(THEOS)/makefiles/common.mk

SOURCE_FILES=$(wildcard tweak/*.m tweak/*.mm tweak/*.x tweak/*.xm)

TWEAK_NAME = Consolidation
Consolidation_FILES = $(SOURCE_FILES)
Consolidation_FRAMEWORKS = UIKit CoreFoundation CoreGraphics CoreTelephony QuartzCore AudioToolbox
Consolidation_PRIVATE_FRAMEWORKS = BulletinBoard
Consolidation_LDFLAGS += -lCSPreferencesProvider
ADDITIONAL_OBJCFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"