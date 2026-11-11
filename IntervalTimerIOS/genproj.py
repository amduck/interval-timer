#!/usr/bin/env python3
"""Generate IntervalTimer.xcodeproj (app + widget extension + watch app) for the files in IntervalTimerIOS/."""
import hashlib, os, sys

OUT = sys.argv[1]                      # IntervalTimerIOS directory (project lives inside it)
TEAM = sys.argv[2] if len(sys.argv) > 2 else ""
APP_ID = "com.amduck.intervaltimer"
EXT_ID = APP_ID + ".widget"
WATCH_ID = APP_ID + ".watchkitapp"

def uid(name):
    return hashlib.sha1(("intervaltimer:" + name).encode()).hexdigest()[:24].upper()

APP_SRC = ["IntervalTimerApp.swift", "ContentView.swift", "TimerModel.swift", "AudioCue.swift",
           "AlertScheduler.swift", "LiveActivityController.swift", "IntervalActivityAttributes.swift",
           "SharedModels.swift", "SyncBridge.swift"]
EXT_SRC = ["Widget/IntervalWidgetBundle.swift", "Widget/IntervalLiveActivity.swift", "IntervalActivityAttributes.swift"]
WATCH_SRC = ["Watch/IntervalWatchApp.swift", "Watch/WatchTimerModel.swift", "Watch/WatchContentView.swift",
             "SharedModels.swift", "SyncBridge.swift"]
ALL_SRC = list(dict.fromkeys(APP_SRC + EXT_SRC + WATCH_SRC))
PLISTS = {"App-Info.plist": "App-Info.plist", "Widget/Widget-Info.plist": "Widget/Widget-Info.plist",
          "Watch/Watch-Info.plist": "Watch/Watch-Info.plist"}

for f in ALL_SRC + list(PLISTS) + ["Assets.xcassets/AppIcon.appiconset/Contents.json", "Watch/Assets.xcassets/AppIcon.appiconset/Contents.json"]:
    assert os.path.exists(os.path.join(OUT, f)), f

# ---- ids
FREF = {f: uid("fref:" + f) for f in ALL_SRC}
PREF = {p: uid("pref:" + p) for p in PLISTS}
APP_PRODUCT, EXT_PRODUCT, WATCH_PRODUCT = uid("product:app"), uid("product:ext"), uid("product:watch")
BF_WATCH = {f: uid("bf:watch:" + f) for f in WATCH_SRC}
BF_EMBED_WATCH = uid("bf:embed:watch")
BF_ASSET_APP, BF_ASSET_WATCH = uid("bf:asset:app"), uid("bf:asset:watch")
FREF_ASSET_APP, FREF_ASSET_WATCH = uid("fref:asset:app"), uid("fref:asset:watch")
G_WATCH, T_WATCH = uid("g:watch"), uid("t:watch")
PH_WATCH_SRC, PH_WATCH_FW, PH_WATCH_RES, PH_EMBED_WATCH = uid("ph:watch:src"), uid("ph:watch:fw"), uid("ph:watch:res"), uid("ph:embed:watch")
CL_WATCH, C_WATCH_D, C_WATCH_R = uid("cl:watch"), uid("c:watch:d"), uid("c:watch:r")
PROXY_W, DEP_W = uid("proxy:watch"), uid("dep:watch")
BF_APP = {f: uid("bf:app:" + f) for f in APP_SRC}
BF_EXT = {f: uid("bf:ext:" + f) for f in EXT_SRC}
BF_EMBED = uid("bf:embed")
G_ROOT, G_APP, G_WIDGET, G_PRODUCTS = uid("g:root"), uid("g:app"), uid("g:widget"), uid("g:products")
T_APP, T_EXT = uid("t:app"), uid("t:ext")
PH_APP_SRC, PH_APP_FW, PH_APP_RES, PH_EMBED = uid("ph:app:src"), uid("ph:app:fw"), uid("ph:app:res"), uid("ph:embed")
PH_EXT_SRC, PH_EXT_FW, PH_EXT_RES = uid("ph:ext:src"), uid("ph:ext:fw"), uid("ph:ext:res")
PROJECT = uid("project")
CL_PROJ, CL_APP, CL_EXT = uid("cl:proj"), uid("cl:app"), uid("cl:ext")
C_PROJ_D, C_PROJ_R = uid("c:proj:d"), uid("c:proj:r")
C_APP_D, C_APP_R = uid("c:app:d"), uid("c:app:r")
C_EXT_D, C_EXT_R = uid("c:ext:d"), uid("c:ext:r")
PROXY, DEP = uid("proxy"), uid("dep")

def q(s):
    return '"%s"' % s.replace('"', '\\"')

def fileref(f, name=None, ftype="sourcecode.swift"):
    base = os.path.basename(f)
    return f'\t\t{FREF[f] if f in FREF else PREF[f]} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {q(base)}; sourceTree = "<group>"; }};\n'

o = []
o.append("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n\n")

# PBXBuildFile
o.append("/* Begin PBXBuildFile section */\n")
for f in APP_SRC:
    o.append(f"\t\t{BF_APP[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {FREF[f]} /* {os.path.basename(f)} */; }};\n")
for f in EXT_SRC:
    o.append(f"\t\t{BF_EXT[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {FREF[f]} /* {os.path.basename(f)} */; }};\n")
o.append(f"\t\t{BF_EMBED} /* IntervalWidget.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {EXT_PRODUCT} /* IntervalWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n")
for f in WATCH_SRC:
    o.append(f"\t\t{BF_WATCH[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {FREF[f]} /* {os.path.basename(f)} */; }};\n")
o.append(f"\t\t{BF_EMBED_WATCH} /* IntervalWatch.app in Embed Watch Content */ = {{isa = PBXBuildFile; fileRef = {WATCH_PRODUCT} /* IntervalWatch.app */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n")
o.append(f"\t\t{BF_ASSET_APP} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {FREF_ASSET_APP} /* Assets.xcassets */; }};\n")
o.append(f"\t\t{BF_ASSET_WATCH} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {FREF_ASSET_WATCH} /* Assets.xcassets */; }};\n")
o.append("/* End PBXBuildFile section */\n\n")

# PBXContainerItemProxy
o.append("/* Begin PBXContainerItemProxy section */\n")
o.append(f"\t\t{PROXY} /* PBXContainerItemProxy */ = {{\n\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {PROJECT} /* Project object */;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = {T_EXT};\n\t\t\tremoteInfo = IntervalWidget;\n\t\t}};\n")
o.append(f"\t\t{PROXY_W} /* PBXContainerItemProxy */ = {{\n\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {PROJECT} /* Project object */;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = {T_WATCH};\n\t\t\tremoteInfo = IntervalWatch;\n\t\t}};\n")
o.append("/* End PBXContainerItemProxy section */\n\n")

# PBXCopyFilesBuildPhase
o.append("/* Begin PBXCopyFilesBuildPhase section */\n")
o.append(f"\t\t{PH_EMBED} /* Embed Foundation Extensions */ = {{\n\t\t\tisa = PBXCopyFilesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tdstPath = \"\";\n\t\t\tdstSubfolderSpec = 13;\n\t\t\tfiles = (\n\t\t\t\t{BF_EMBED} /* IntervalWidget.appex in Embed Foundation Extensions */,\n\t\t\t);\n\t\t\tname = \"Embed Foundation Extensions\";\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
o.append(f"\t\t{PH_EMBED_WATCH} /* Embed Watch Content */ = {{\n\t\t\tisa = PBXCopyFilesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tdstPath = \"$(CONTENTS_FOLDER_PATH)/Watch\";\n\t\t\tdstSubfolderSpec = 16;\n\t\t\tfiles = (\n\t\t\t\t{BF_EMBED_WATCH} /* IntervalWatch.app in Embed Watch Content */,\n\t\t\t);\n\t\t\tname = \"Embed Watch Content\";\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
o.append("/* End PBXCopyFilesBuildPhase section */\n\n")

# PBXFileReference
o.append("/* Begin PBXFileReference section */\n")
for f in ALL_SRC:
    o.append(fileref(f))
for p in PLISTS:
    o.append(fileref(p, ftype="text.plist.xml"))
o.append(f"\t\t{APP_PRODUCT} /* IntervalTimer.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = IntervalTimer.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n")
o.append(f"\t\t{EXT_PRODUCT} /* IntervalWidget.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = IntervalWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n")
o.append(f"\t\t{WATCH_PRODUCT} /* IntervalWatch.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = IntervalWatch.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n")
o.append(f"\t\t{FREF_ASSET_APP} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};\n")
o.append(f"\t\t{FREF_ASSET_WATCH} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};\n")
o.append("/* End PBXFileReference section */\n\n")

# Frameworks phases
o.append("/* Begin PBXFrameworksBuildPhase section */\n")
for ph in (PH_APP_FW, PH_EXT_FW, PH_WATCH_FW):
    o.append(f"\t\t{ph} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
o.append("/* End PBXFrameworksBuildPhase section */\n\n")

# Groups
def gchildren(files):
    return "".join(f"\t\t\t\t{FREF[f] if f in FREF else PREF[f]} /* {os.path.basename(f)} */,\n" for f in files)
o.append("/* Begin PBXGroup section */\n")
o.append(f"\t\t{G_ROOT} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{G_APP} /* IntervalTimer */,\n\t\t\t\t{G_WIDGET} /* IntervalWidget */,\n\t\t\t\t{G_WATCH} /* IntervalWatch */,\n\t\t\t\t{G_PRODUCTS} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
app_files = APP_SRC + ["App-Info.plist"]
o.append(f"\t\t{G_APP} /* IntervalTimer */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{gchildren(app_files)}\t\t\t\t{FREF_ASSET_APP} /* Assets.xcassets */,\n\t\t\t);\n\t\t\tname = IntervalTimer;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
widget_files = ["Widget/IntervalWidgetBundle.swift", "Widget/IntervalLiveActivity.swift", "Widget/Widget-Info.plist"]
o.append(f"\t\t{G_WIDGET} /* IntervalWidget */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{gchildren(widget_files)}\t\t\t);\n\t\t\tname = IntervalWidget;\n\t\t\tpath = Widget;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
watch_files = ["Watch/IntervalWatchApp.swift", "Watch/WatchTimerModel.swift", "Watch/WatchContentView.swift", "Watch/Watch-Info.plist"]
o.append(f"\t\t{G_WATCH} /* IntervalWatch */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{gchildren(watch_files)}\t\t\t\t{FREF_ASSET_WATCH} /* Assets.xcassets */,\n\t\t\t);\n\t\t\tname = IntervalWatch;\n\t\t\tpath = Watch;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
o.append(f"\t\t{G_PRODUCTS} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{APP_PRODUCT} /* IntervalTimer.app */,\n\t\t\t\t{EXT_PRODUCT} /* IntervalWidget.appex */,\n\t\t\t\t{WATCH_PRODUCT} /* IntervalWatch.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
o.append("/* End PBXGroup section */\n\n")

# Native targets
o.append("/* Begin PBXNativeTarget section */\n")
o.append(f"""\t\t{T_APP} /* IntervalTimer */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {CL_APP} /* Build configuration list for PBXNativeTarget "IntervalTimer" */;
\t\t\tbuildPhases = (
\t\t\t\t{PH_APP_SRC} /* Sources */,
\t\t\t\t{PH_APP_FW} /* Frameworks */,
\t\t\t\t{PH_APP_RES} /* Resources */,
\t\t\t\t{PH_EMBED} /* Embed Foundation Extensions */,
\t\t\t\t{PH_EMBED_WATCH} /* Embed Watch Content */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{DEP} /* PBXTargetDependency */,
\t\t\t\t{DEP_W} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = IntervalTimer;
\t\t\tproductName = IntervalTimer;
\t\t\tproductReference = {APP_PRODUCT} /* IntervalTimer.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
\t\t{T_EXT} /* IntervalWidget */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {CL_EXT} /* Build configuration list for PBXNativeTarget "IntervalWidget" */;
\t\t\tbuildPhases = (
\t\t\t\t{PH_EXT_SRC} /* Sources */,
\t\t\t\t{PH_EXT_FW} /* Frameworks */,
\t\t\t\t{PH_EXT_RES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = IntervalWidget;
\t\t\tproductName = IntervalWidget;
\t\t\tproductReference = {EXT_PRODUCT} /* IntervalWidget.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
\t\t{T_WATCH} /* IntervalWatch */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {CL_WATCH} /* Build configuration list for PBXNativeTarget "IntervalWatch" */;
\t\t\tbuildPhases = (
\t\t\t\t{PH_WATCH_SRC} /* Sources */,
\t\t\t\t{PH_WATCH_FW} /* Frameworks */,
\t\t\t\t{PH_WATCH_RES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = IntervalWatch;
\t\t\tproductName = IntervalWatch;
\t\t\tproductReference = {WATCH_PRODUCT} /* IntervalWatch.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
""")
o.append("/* End PBXNativeTarget section */\n\n")

# Project
o.append("/* Begin PBXProject section */\n")
o.append(f"""\t\t{PROJECT} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{T_APP} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t\t{T_EXT} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t\t{T_WATCH} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {CL_PROJ} /* Build configuration list for PBXProject "IntervalTimer" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {G_ROOT};
\t\t\tproductRefGroup = {G_PRODUCTS} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{T_APP} /* IntervalTimer */,
\t\t\t\t{T_EXT} /* IntervalWidget */,
\t\t\t\t{T_WATCH} /* IntervalWatch */,
\t\t\t);
\t\t}};
""")
o.append("/* End PBXProject section */\n\n")

# Resources (empty)
o.append("/* Begin PBXResourcesBuildPhase section */\n")
for ph, extra in ((PH_APP_RES, f"\t\t\t\t{BF_ASSET_APP} /* Assets.xcassets in Resources */,\n"), (PH_EXT_RES, ""), (PH_WATCH_RES, f"\t\t\t\t{BF_ASSET_WATCH} /* Assets.xcassets in Resources */,\n")):
    o.append(f"\t\t{ph} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{extra}\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
o.append("/* End PBXResourcesBuildPhase section */\n\n")

# Sources
o.append("/* Begin PBXSourcesBuildPhase section */\n")
def sources(ph, files, bf):
    s = f"\t\t{ph} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
    for f in files:
        s += f"\t\t\t\t{bf[f]} /* {os.path.basename(f)} in Sources */,\n"
    return s + "\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n"
o.append(sources(PH_APP_SRC, APP_SRC, BF_APP))
o.append(sources(PH_EXT_SRC, EXT_SRC, BF_EXT))
o.append(sources(PH_WATCH_SRC, WATCH_SRC, BF_WATCH))
o.append("/* End PBXSourcesBuildPhase section */\n\n")

# Target dependency
o.append("/* Begin PBXTargetDependency section */\n")
o.append(f"\t\t{DEP} /* PBXTargetDependency */ = {{\n\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = {T_EXT} /* IntervalWidget */;\n\t\t\ttargetProxy = {PROXY} /* PBXContainerItemProxy */;\n\t\t}};\n")
o.append(f"\t\t{DEP_W} /* PBXTargetDependency */ = {{\n\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = {T_WATCH} /* IntervalWatch */;\n\t\t\ttargetProxy = {PROXY_W} /* PBXContainerItemProxy */;\n\t\t}};\n")
o.append("/* End PBXTargetDependency section */\n\n")

# Build configurations
def settings(d):
    s = ""
    for k in sorted(d):
        v = d[k]
        if isinstance(v, list):
            s += f"\t\t\t\t{k} = (\n" + "".join(f"\t\t\t\t\t{q(x)},\n" for x in v) + "\t\t\t\t);\n"
        else:
            vs = str(v)
            need = (not vs.replace("_", "").replace(".", "").replace("/", "").isalnum()) or vs == ""
            s += f"\t\t\t\t{k} = {q(vs) if need else vs};\n"
    return s

def config(cid, name, d):
    return f"\t\t{cid} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{settings(d)}\t\t\t}};\n\t\t\tname = {name};\n\t\t}};\n"

common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO", "ENABLE_STRICT_OBJC_MSGSEND": "YES", "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0",
}
proj_debug = dict(common, DEBUG_INFORMATION_FORMAT="dwarf", ENABLE_TESTABILITY="YES", GCC_OPTIMIZATION_LEVEL="0",
                  MTL_ENABLE_DEBUG_INFO="INCLUDE_SOURCE", ONLY_ACTIVE_ARCH="YES",
                  SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG $(inherited)", SWIFT_OPTIMIZATION_LEVEL="-Onone")
proj_release = dict(common, DEBUG_INFORMATION_FORMAT="dwarf-with-dsym", ENABLE_NS_ASSERTIONS="NO", MTL_ENABLE_DEBUG_INFO="NO",
                    SWIFT_COMPILATION_MODE="wholemodule", VALIDATE_PRODUCT="YES")

def target_settings(bundle_id, plist, ext):
    d = {
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": plist, "MARKETING_VERSION": "1.0", "PRODUCT_BUNDLE_IDENTIFIER": bundle_id,
        "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS": "YES", "TARGETED_DEVICE_FAMILY": "1",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"] + (["@executable_path/../../Frameworks"] if ext else []),
    }
    if TEAM:
        d["DEVELOPMENT_TEAM"] = TEAM
    if ext:
        d["SKIP_INSTALL"] = "YES"
    return d

def app_settings():
    d = target_settings(APP_ID, "App-Info.plist", False)
    d["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    return d

def watch_settings():
    d = target_settings(WATCH_ID, "Watch/Watch-Info.plist", False)
    d.update({
        "SDKROOT": "watchos", "TARGETED_DEVICE_FAMILY": "4", "WATCHOS_DEPLOYMENT_TARGET": "10.0",
        "SUPPORTED_PLATFORMS": "watchos watchsimulator", "SKIP_INSTALL": "YES",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    })
    return d

o.append("/* Begin XCBuildConfiguration section */\n")
o.append(config(C_PROJ_D, "Debug", proj_debug)); o.append(config(C_PROJ_R, "Release", proj_release))
o.append(config(C_APP_D, "Debug", app_settings()))
o.append(config(C_APP_R, "Release", app_settings()))
o.append(config(C_EXT_D, "Debug", target_settings(EXT_ID, "Widget/Widget-Info.plist", True)))
o.append(config(C_EXT_R, "Release", target_settings(EXT_ID, "Widget/Widget-Info.plist", True)))
o.append(config(C_WATCH_D, "Debug", watch_settings())); o.append(config(C_WATCH_R, "Release", watch_settings()))
o.append("/* End XCBuildConfiguration section */\n\n")

o.append("/* Begin XCConfigurationList section */\n")
def clist(cid, label, d, r):
    return f"\t\t{cid} /* Build configuration list for {label} */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{d} /* Debug */,\n\t\t\t\t{r} /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};\n"
o.append(clist(CL_PROJ, 'PBXProject "IntervalTimer"', C_PROJ_D, C_PROJ_R))
o.append(clist(CL_APP, 'PBXNativeTarget "IntervalTimer"', C_APP_D, C_APP_R))
o.append(clist(CL_EXT, 'PBXNativeTarget "IntervalWidget"', C_EXT_D, C_EXT_R))
o.append(clist(CL_WATCH, 'PBXNativeTarget "IntervalWatch"', C_WATCH_D, C_WATCH_R))
o.append("/* End XCConfigurationList section */\n")
o.append(f"\t}};\n\trootObject = {PROJECT} /* Project object */;\n}}\n")

proj = os.path.join(OUT, "IntervalTimer.xcodeproj")
os.makedirs(proj, exist_ok=True)
open(os.path.join(proj, "project.pbxproj"), "w").write("".join(o))

PLIST_HEAD = '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n'
COMMON_KEYS = """\t<key>CFBundleDevelopmentRegion</key>\n\t<string>en</string>
\t<key>CFBundleExecutable</key>\n\t<string>$(EXECUTABLE_NAME)</string>
\t<key>CFBundleIdentifier</key>\n\t<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
\t<key>CFBundleInfoDictionaryVersion</key>\n\t<string>6.0</string>
\t<key>CFBundleName</key>\n\t<string>$(PRODUCT_NAME)</string>
\t<key>CFBundlePackageType</key>\n\t<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
\t<key>CFBundleShortVersionString</key>\n\t<string>$(MARKETING_VERSION)</string>
\t<key>CFBundleVersion</key>\n\t<string>$(CURRENT_PROJECT_VERSION)</string>
"""
app_plist = PLIST_HEAD + COMMON_KEYS + """\t<key>CFBundleDisplayName</key>\n\t<string>Interval Timer</string>
\t<key>LSRequiresIPhoneOS</key>\n\t<true/>
\t<key>NSSupportsLiveActivities</key>\n\t<true/>
\t<key>UIApplicationSceneManifest</key>\n\t<dict>\n\t\t<key>UIApplicationSupportsMultipleScenes</key>\n\t\t<false/>\n\t</dict>
\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>audio</string>\n\t</array>
\t<key>UILaunchScreen</key>\n\t<dict/>
\t<key>UISupportedInterfaceOrientations</key>\n\t<array>\n\t\t<string>UIInterfaceOrientationPortrait</string>\n\t</array>
</dict>\n</plist>\n"""
ext_plist = PLIST_HEAD + COMMON_KEYS + """\t<key>CFBundleDisplayName</key>\n\t<string>Interval Widget</string>
\t<key>NSExtension</key>\n\t<dict>\n\t\t<key>NSExtensionPointIdentifier</key>\n\t\t<string>com.apple.widgetkit-extension</string>\n\t</dict>
</dict>\n</plist>\n"""
open(os.path.join(OUT, "App-Info.plist"), "w").write(app_plist)
open(os.path.join(OUT, "Widget", "Widget-Info.plist"), "w").write(ext_plist)
print("generated", proj, "team=", TEAM or "(none)")
