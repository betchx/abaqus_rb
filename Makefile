
SHELL = /bin/sh

#### Start of system configuration section. ####

srcdir = .
topdir = /usr/lib/ruby/1.8/i386-cygwin
hdrdir = $(topdir)
VPATH = $(srcdir):$(topdir):$(hdrdir)
exec_prefix = $(prefix)
prefix = $(DESTDIR)/usr
sharedstatedir = $(prefix)/com
mandir = $(prefix)/share/man
psdir = $(docdir)
oldincludedir = $(DESTDIR)/usr/include
localedir = $(datarootdir)/locale
bindir = $(exec_prefix)/bin
libexecdir = $(prefix)/sbin
sitedir = $(libdir)/ruby/site_ruby
htmldir = $(docdir)
vendorarchdir = $(vendorlibdir)/$(sitearch)
includedir = $(prefix)/include
infodir = $(prefix)/share/info
vendorlibdir = $(vendordir)/$(ruby_version)
sysconfdir = $(DESTDIR)/etc
libdir = $(exec_prefix)/lib
sbindir = $(exec_prefix)/sbin
rubylibdir = $(libdir)/ruby/$(ruby_version)
docdir = $(datarootdir)/doc/$(PACKAGE)
dvidir = $(docdir)
vendordir = $(libdir)/ruby/vendor_ruby
datarootdir = $(prefix)/share
pdfdir = $(docdir)
archdir = $(rubylibdir)/$(arch)
sitearchdir = $(sitelibdir)/$(sitearch)
datadir = $(prefix)/share
localstatedir = $(DESTDIR)/var
sitelibdir = $(sitedir)/$(ruby_version)

CC = gcc
LIBRUBY = lib$(RUBY_SO_NAME).dll.a
LIBRUBY_A = lib$(RUBY_SO_NAME)-static.a
LIBRUBYARG_SHARED = -l$(RUBY_SO_NAME)
LIBRUBYARG_STATIC = -l$(RUBY_SO_NAME)-static

RUBY_EXTCONF_H = 
CFLAGS   =  -g -O2  $(cflags) 
INCFLAGS = -I. -I$(topdir) -I$(hdrdir) -I$(srcdir)
DEFS     = 
CPPFLAGS =   $(DEFS) $(cppflags)
CXXFLAGS = $(CFLAGS) 
ldflags  = -L. 
dldflags =  -Wl,--enable-auto-image-base,--enable-auto-import,--export-all
archflag = 
DLDFLAGS = $(ldflags) $(dldflags) $(archflag)
LDSHARED = gcc -shared -s
AR = ar
EXEEXT = .exe

RUBY_INSTALL_NAME = ruby
RUBY_SO_NAME = ruby
arch = i386-cygwin
sitearch = i386-cygwin
ruby_version = 1.8
ruby = /usr/bin/ruby
RUBY = $(ruby)
RM = rm -f
MAKEDIRS = mkdir -p
INSTALL = /usr/bin/install -c
INSTALL_PROG = $(INSTALL) -m 0755
INSTALL_DATA = $(INSTALL) -m 644
COPY = cp

#### End of system configuration section. ####

preload = 

libpath = . $(libdir)
LIBPATH =  -L. -L$(libdir)
DEFFILE = 

CLEANFILES = mkmf.log
DISTCLEANFILES = 

extout = 
extout_prefix = 
target_prefix = 
LOCAL_LIBS = 
LIBS = $(LIBRUBYARG_SHARED)  -ldl -lcrypt  
SRCS = 
OBJS = 
TARGET = 
DLLIB = 
EXTSTATIC = 
STATIC_LIB = 

BINDIR        = $(bindir)
RUBYCOMMONDIR = $(sitedir)$(target_prefix)
RUBYLIBDIR    = $(sitelibdir)$(target_prefix)
RUBYARCHDIR   = $(sitearchdir)$(target_prefix)

TARGET_SO     = $(DLLIB)
CLEANLIBS     = $(TARGET).so $(TARGET).il? $(TARGET).tds $(TARGET).map
CLEANOBJS     = *.o *.a *.s[ol] *.pdb *.exp *.bak

all:		Makefile
static:		$(STATIC_LIB)

clean:
		@-$(RM) $(CLEANLIBS) $(CLEANOBJS) $(CLEANFILES)

distclean:	clean
		@-$(RM) Makefile $(RUBY_EXTCONF_H) conftest.* mkmf.log
		@-$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES)

realclean:	distclean
install: install-so install-rb

install-so: Makefile
install-rb: pre-install-rb install-rb-default
install-rb-default: pre-install-rb-default
pre-install-rb: Makefile
pre-install-rb-default: Makefile
pre-install-rb-default: $(RUBYLIBDIR)/abaqus
install-rb-default: $(RUBYLIBDIR)/abaqus/bc.rb
$(RUBYLIBDIR)/abaqus/bc.rb: $(srcdir)/lib/abaqus/bc.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/bc.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/bind.rb
$(RUBYLIBDIR)/abaqus/bind.rb: $(srcdir)/lib/abaqus/bind.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/bind.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/element.rb
$(RUBYLIBDIR)/abaqus/element.rb: $(srcdir)/lib/abaqus/element.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/element.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/elset.rb
$(RUBYLIBDIR)/abaqus/elset.rb: $(srcdir)/lib/abaqus/elset.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/elset.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/inp.rb
$(RUBYLIBDIR)/abaqus/inp.rb: $(srcdir)/lib/abaqus/inp.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/inp.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/load.rb
$(RUBYLIBDIR)/abaqus/load.rb: $(srcdir)/lib/abaqus/load.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/load.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/material.rb
$(RUBYLIBDIR)/abaqus/material.rb: $(srcdir)/lib/abaqus/material.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/material.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/model.rb
$(RUBYLIBDIR)/abaqus/model.rb: $(srcdir)/lib/abaqus/model.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/model.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/node.rb
$(RUBYLIBDIR)/abaqus/node.rb: $(srcdir)/lib/abaqus/node.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/node.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/nset.rb
$(RUBYLIBDIR)/abaqus/nset.rb: $(srcdir)/lib/abaqus/nset.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/nset.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/property.rb
$(RUBYLIBDIR)/abaqus/property.rb: $(srcdir)/lib/abaqus/property.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/property.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/step.rb
$(RUBYLIBDIR)/abaqus/step.rb: $(srcdir)/lib/abaqus/step.rb $(RUBYLIBDIR)/abaqus
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/step.rb $(@D)
pre-install-rb-default: $(RUBYLIBDIR)/abaqus/element
install-rb-default: $(RUBYLIBDIR)/abaqus/element/base.rb
$(RUBYLIBDIR)/abaqus/element/base.rb: $(srcdir)/lib/abaqus/element/base.rb $(RUBYLIBDIR)/abaqus/element
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/element/base.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/element/s4.rb
$(RUBYLIBDIR)/abaqus/element/s4.rb: $(srcdir)/lib/abaqus/element/s4.rb $(RUBYLIBDIR)/abaqus/element
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/element/s4.rb $(@D)
install-rb-default: $(RUBYLIBDIR)/abaqus/element/s8.rb
$(RUBYLIBDIR)/abaqus/element/s8.rb: $(srcdir)/lib/abaqus/element/s8.rb $(RUBYLIBDIR)/abaqus/element
	$(INSTALL_DATA) $(srcdir)/lib/abaqus/element/s8.rb $(@D)
pre-install-rb-default: $(RUBYLIBDIR)
install-rb-default: $(RUBYLIBDIR)/abaqus.rb
$(RUBYLIBDIR)/abaqus.rb: $(srcdir)/lib/abaqus.rb $(RUBYLIBDIR)
	$(INSTALL_DATA) $(srcdir)/lib/abaqus.rb $(@D)
$(RUBYLIBDIR)/abaqus:
	$(MAKEDIRS) $@
$(RUBYLIBDIR)/abaqus/element:
	$(MAKEDIRS) $@
$(RUBYLIBDIR):
	$(MAKEDIRS) $@

site-install: site-install-so site-install-rb
site-install-so: install-so
site-install-rb: install-rb

