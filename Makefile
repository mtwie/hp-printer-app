#
# Makefile for the HP Printer Application
#
# Copyright © 2020-2022 by Michael R Sweet
#
# Licensed under Apache License v2.0.  See the file "LICENSE" for more
# information.
#

# POSIX makefile
.POSIX:

# Build silently
.SILENT:

# Version and directories...
VERSION		=	1.2
prefix		=	$(DESTDIR)/usr/local
includedir	=	$(prefix)/include
bindir		=	$(prefix)/bin
libdir		=	$(prefix)/lib
mandir		=	$(prefix)/share/man
unitdir 	=	`pkg-config --variable=systemdsystemunitdir systemd`


# Compiler/linker options...
CSFLAGS		=	-s "$${CODESIGN_IDENTITY:=-}" --timestamp -o runtime
OPTIM		=	-g
CFLAGS		=	$(CPPFLAGS) $(OPTIM)
CPPFLAGS	=	'-DVERSION="$(VERSION)"' `cups-config --cflags` `pkg-config --cflags pappl`
LDFLAGS		=	$(OPTIM) `cups-config --ldflags`
LIBS		=	`pkg-config --libs pappl` `cups-config --image --libs`


# Targets...
OBJS		=	hp-printer-app.o
TARGETS		=	hp-printer-app


# General build rules...
.SUFFIXES:	.c .o
.c.o:
	echo "Compiling $<..."
	$(CC) $(CFLAGS) -c -o $@ $<


# Targets...
all:		$(TARGETS)

clean:
	echo "Cleaning all output..."
	rm -f $(TARGETS) $(OBJS)

install:	$(TARGETS)
	echo "Installing program to $(bindir)..."
	mkdir -p $(bindir)
	cp $(TARGETS) $(bindir)
	echo "Installing documentation to $(mandir)..."
	mkdir -p $(mandir)/man1
	cp hp-printer-app.1 $(mandir)/man1
	if test "x$(unitdir)" != x; then \
		echo "Installing systemd service to $(unitdir)..."; \
		mkdir -p $(unitdir); \
		cp hp-printer-app.service $(unitdir); \
	fi

hp-printer-app:	$(OBJS)
	echo "Linking $@..."
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)

$(OBJS):	Makefile


# Bundle and notarize the hp-printer-app executable and make the macOS package...
#
# Set the APPLEID, CODESIGN_IDENTITY, PKGSIGN_IDENTITY, and TEAMID environment
# variables from the Apple developer pages.
macos:
	make clean
	make OPTIM="-g -Os -mmacosx-version-min=10.14 -arch x86_64 -arch arm64" all
	echo "Creating macOS app bundle..."
	rm -rf /private/tmp/hp-printer-app-$(VERSION)
	make DESTDIR="/private/tmp/hp-printer-app-$(VERSION)" install
	mkdir -p "/private/tmp/hp-printer-app-$(VERSION)/Applications/HP Printer App.app/Contents/MacOS"
	mv "/private/tmp/hp-printer-app-$(VERSION)/usr/local/bin/hp-printer-app" "/private/tmp/hp-printer-app-$(VERSION)/Applications/HP Printer App.app/Contents/MacOS"
	mkdir -p "/private/tmp/hp-printer-app-$(VERSION)/Applications/HP Printer App.app/Contents/Resources"
	cp hp-printer-app.icns "/private/tmp/hp-printer-app-$(VERSION)/Applications/HP Printer App.app/Contents/Resources"
	sed -e '1,$$s/@VERSION@/$(VERSION)/' <hp-printer-app.plist.in >"/private/tmp/hp-printer-app-$(VERSION)/Applications/HP Printer App.app/Contents/Info.plist"
	ln -s "/Applications/HP Printer App.app/Contents/MacOS/hp-printer-app" "/private/tmp/hp-printer-app-$(VERSION)/usr/local/bin/hp-printer-app"
	echo "Signing macOS app bundle..."
	codesign $(CSFLAGS) "/private/tmp/hp-printer-app-$(VERSION)/Applications/HP Printer App.app"
	echo "Creating archive for notarization..."
	rm -f hp-printer-app.zip
	ditto -c -k --keepParent "/private/tmp/hp-printer-app-$(VERSION)/Applications/HP Printer App.app" hp-printer-app.zip
	echo Notarizing application
	xcrun notarytool submit hp-printer-app.zip \
	    --apple-id "$${APPLEID}" \
	    --keychain-profile "AC_$${TEAMID}" \
	    --team-id "$${TEAMID}" \
	    --wait
	rm -f hp-printer-app.zip
	echo "Creating the macOS package..."
	pkgbuild --root /private/tmp/hp-printer-app-$(VERSION) \
	    --identifier org.msweet.hp-printer-app \
	    --version $(VERSION) \
	    --min-os-version 10.14 \
	    --sign "$${PKGSIGN_IDENTITY}" --timestamp \
	    hp-printer-app-$(VERSION)-macos.pkg
