DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME := rootless

THEOS_DEVICE_IP = 192.168.0.23

TARGET := iphone:clang:latest:15.0

INSTALL_TARGET_PROCESSES = appstorecomponentsd installd managedappdistributiond MobileStorageMounter

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = aintuitweaks

aintuitweaks_FILES = BypassMarketplace.x FixDDI.x
aintuitweaks_CFLAGS = -fobjc-arc
aintuitweaks_FRAMEWORKS = IOKit
aintuitweaks_LIBRARIES = image4
aintuitweaks_CODESIGN_FLAGS = -Cadhoc -S

include $(THEOS_MAKE_PATH)/tweak.mk
