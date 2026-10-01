THEOS ?= $(HOME)/theos
TARGET = iphone:clang:16.5:14.0
ARCHS ?= arm64
SCHEME ?= rootless
ifeq ($(SCHEME),roothide)
export THEOS_PACKAGE_SCHEME = roothide
else ifeq ($(SCHEME),rootless)
export THEOS_PACKAGE_SCHEME = rootless
else ifeq ($(SCHEME),rootful)
unexport THEOS_PACKAGE_SCHEME
else
$(error Unknown SCHEME=$(SCHEME); use rootless, rootful, or roothide)
endif
export DEBUG = 0
INSTALL_TARGET_PROCESSES = Aweme
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = LickingDog
LickingDog_FILES = $(wildcard Sources/*.m) Sources/LDPolicy.c
LickingDog_CFLAGS = -Wall -Wextra -Werror -Wno-unused-parameter -Wno-deprecated-declarations -ISources
LickingDog_OBJCFLAGS = -fobjc-arc
LickingDog_FRAMEWORKS = UIKit Foundation QuartzCore ImageIO
LickingDog_LDFLAGS = -lobjc
include $(THEOS_MAKE_PATH)/tweak.mk

# Reuse the cached package version to avoid incrementing the build counter twice.
LD_PACKAGE_FILENAME_VERSION = $(patsubst $(THEOS_PACKAGE_BASE_VERSION)-%,$(THEOS_PACKAGE_BASE_VERSION)-build%,$(_THEOS_INTERNAL_PACKAGE_VERSION))
_THEOS_DEB_PACKAGE_FILENAME = $(THEOS_PACKAGE_DIR)/DYLickingDog-$(LD_PACKAGE_FILENAME_VERSION)-$(SCHEME).deb

# Normalize staging permissions in the same fakeroot session used for packaging.
ifeq ($(shell uname -s),Linux)
define LD_PACKAGE_PERMISSIONS
set -eu
test -f "$$1/DEBIAN/control"
for stage in "$$@"; do
    [ -d "$$stage" ] || continue
    find "$$stage" -type d -exec chmod 0755 {} +
    find "$$stage" -type f -exec chmod 0644 {} +
    find "$$stage" -type f -name '*.dylib' -exec chmod 0755 {} +
    chown -hR 0:0 "$$stage"
done
for script in preinst postinst prerm postrm config; do
    if [ -f "$$1/DEBIAN/$$script" ]; then chmod 0755 "$$1/DEBIAN/$$script"; fi
done
endef
before-package::
	$(file >$(_THEOS_LOCAL_DATA_DIR)/package-permissions.sh,$(LD_PACKAGE_PERMISSIONS))
	$(ECHO_NOTHING)$(FAKEROOT) -r bash "$(_THEOS_LOCAL_DATA_DIR)/package-permissions.sh" "$(THEOS_STAGING_DIR)" "$(_THEOS_STAGING_TMP)"$(ECHO_END)
endif

ifeq ($(_THEOS_FINAL_PACKAGE),$(_THEOS_TRUE))
ifeq ($(SCHEME),rootless)
after-package::
	@set -eu; \
	for old in "$(THEOS_PACKAGE_DIR)"/DYLickingDog-*-rootless.deb; do \
		[ -f "$$old" ] || continue; \
		case "$$old" in *-build*-rootless.deb) continue ;; esac; \
		[ "$$old" != "$(_THEOS_DEB_PACKAGE_FILENAME)" ] || continue; \
		archive="$(THEOS_PROJECT_DIR)/.validation/package-history"; \
		mkdir -p "$$archive"; \
		backup=$$(mktemp "$$archive/$$(basename "$$old").XXXXXX"); \
		mv "$$old" "$$backup"; \
	done
endif
endif
