#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"
require "fileutils"

root = File.expand_path("..", __dir__)
project_path = File.join(root, "XiangqiMobile.xcodeproj")
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes["LastSwiftUpdateCheck"] = "2700"
project.root_object.attributes["LastUpgradeCheck"] = "2700"

# Xcode only compiles the String Catalog for regions listed here. Without the
# Chinese regions the translations are silently dropped from the built app.
project.root_object.development_region = "en"
project.root_object.known_regions = %w[en Base zh-Hans zh-Hant]

app_group = project.main_group.new_group("XiangqiMobile", "XiangqiMobile")
target = project.new_target(:application, "XiangqiMobile", :ios, "18.0")
ui_tests = project.new_target(:ui_test_bundle, "XiangqiMobileUITests", :ios, "18.0")
ui_tests.add_dependency(target)

Dir.glob(File.join(root, "XiangqiMobile", "**", "*.swift")).sort.each do |path|
  relative = path.delete_prefix(File.join(root, "XiangqiMobile") + "/")
  components = relative.split("/")
  filename = components.pop
  group = components.reduce(app_group) do |parent, name|
    parent.groups.find { |child| child.display_name == name } || parent.new_group(name, name)
  end
  reference = group.new_file(filename)
  target.source_build_phase.add_file_reference(reference)
end

bridge_group = project.main_group.new_group("EngineBridge", "EngineBridge")
Dir.glob(File.join(root, "EngineBridge", "*"), File::FNM_DOTMATCH).sort.each do |path|
  next unless File.file?(path)
  reference = bridge_group.new_file(File.basename(path))
  target.source_build_phase.add_file_reference(reference) if File.extname(path) == ".cpp"
end

pikafish_group = project.main_group.new_group("Pikafish", "Vendor/Pikafish/src")
pikafish_sources = Dir.glob(File.join(root, "Vendor", "Pikafish", "src", "**", "*.cpp")).sort.reject do |path|
  path.end_with?("/main.cpp") || path.include?("/universal/")
end
pikafish_sources.each do |path|
  relative = path.delete_prefix(File.join(root, "Vendor", "Pikafish", "src") + "/")
  components = relative.split("/")
  filename = components.pop
  group = components.reduce(pikafish_group) do |parent, name|
    parent.groups.find { |child| child.display_name == name } || parent.new_group(name, name)
  end
  target.source_build_phase.add_file_reference(group.new_file(filename))
end

resources_group = project.main_group.new_group("Resources", "Resources")
assets = resources_group.new_file("Assets.xcassets")
target.resources_build_phase.add_file_reference(assets)
[
  ["Engine", "pikafish.nnue"],
  ["Licenses", "Pikafish-GPL-3.0.txt"],
  ["Licenses", "Pikafish-AUTHORS.txt"],
  ["Licenses", "CCPD-CC-BY-4.0.txt"],
  ["Learning", "CCPD-source.json"],
  ["Learning", "ccpd.sqlite3"],
  ["Learning", "ccpd-audit.json"],
  ["Learning", "ccpd-quarantine.jsonl"]
].each do |directory, filename|
  group = resources_group.groups.find { |child| child.display_name == directory } ||
          resources_group.new_group(directory, directory)
  target.resources_build_phase.add_file_reference(group.new_file(filename))
end

# One Localizable.strings per language (Resources/Localizations/<lang>.lproj/),
# so translating one language never touches another's file. Xcode groups them
# as a single variant group in the navigator.
localizations_group = resources_group.groups.find { |child| child.display_name == "Localizations" } ||
                       resources_group.new_group("Localizations", "Localizations")
variant_group = localizations_group.new_variant_group("Localizable.strings")
%w[en zh-Hans zh-Hant].each do |language|
  file_ref = variant_group.new_file("#{language}.lproj/Localizable.strings")
  file_ref.name = language
end
target.resources_build_phase.add_file_reference(variant_group)

tests_group = project.main_group.new_group("Tests", "Tests")
ui_group = tests_group.new_group("XiangqiMobileUITests", "XiangqiMobileUITests")
Dir.glob(File.join(root, "Tests", "XiangqiMobileUITests", "*.swift")).sort.each do |path|
  reference = ui_group.new_file(File.basename(path))
  ui_tests.source_build_phase.add_file_reference(reference)
end

target.build_configurations.each do |config|
  settings = config.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.frankzhu.xiangqi-mobile"
  settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  settings["SWIFT_VERSION"] = "5.0"
  settings["SWIFT_STRICT_CONCURRENCY"] = "complete"
  settings["SWIFT_OBJC_BRIDGING_HEADER"] = "EngineBridge/XiangqiMobile-Bridging-Header.h"
  settings["CLANG_CXX_LANGUAGE_STANDARD"] = "c++17"
  settings["CLANG_CXX_LIBRARY"] = "libc++"
  # Pikafish's NNUE is unusably slow at Clang's Debug default (-O0), even
  # though the surrounding Swift app should remain a normal debug build.
  settings["GCC_OPTIMIZATION_LEVEL"] = "3"
  settings["GCC_PREPROCESSOR_DEFINITIONS"] = ["$(inherited)", "IS_64BIT", "USE_NEON=8"]
  settings["HEADER_SEARCH_PATHS"] = ["$(inherited)", "$(SRCROOT)/EngineBridge", "$(SRCROOT)/Vendor/Pikafish/src"]
  settings["OTHER_LDFLAGS"] = ["$(inherited)", "-lsqlite3", "-lz"]
  settings["GENERATE_INFOPLIST_FILE"] = "YES"
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = "Xiangqi"
  settings["INFOPLIST_KEY_LSApplicationCategoryType"] = "public.app-category.board-games"
  settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
  settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
  settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  settings["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone"] = "UIInterfaceOrientationPortrait"
  settings["TARGETED_DEVICE_FAMILY"] = "1"
  settings["IPHONEOS_DEPLOYMENT_TARGET"] = "18.0"
  settings["MARKETING_VERSION"] = "1.0"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["CODE_SIGN_STYLE"] = "Automatic"
  settings["DEVELOPMENT_TEAM"] = ""
  settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  settings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
end


ui_tests.build_configurations.each do |config|
  settings = config.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.frankzhu.xiangqi-mobile-uitests"
  settings["SWIFT_VERSION"] = "5.0"
  settings["GENERATE_INFOPLIST_FILE"] = "YES"
  settings["TEST_TARGET_NAME"] = "XiangqiMobile"
  settings["IPHONEOS_DEPLOYMENT_TARGET"] = "18.0"
  settings["CODE_SIGN_STYLE"] = "Automatic"
  settings["DEVELOPMENT_TEAM"] = ""
end

project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(ui_tests)
scheme.save_as(project_path, "XiangqiMobile", true)
puts "Generated #{project_path}"
