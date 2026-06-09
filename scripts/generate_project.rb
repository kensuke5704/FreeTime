require "xcodeproj"
require "fileutils"

root = File.expand_path("..", __dir__)
project_path = File.join(root, "FreeTime.xcodeproj")
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes["LastSwiftUpdateCheck"] = "1600"
project.root_object.attributes["LastUpgradeCheck"] = "1600"

app = project.new_target(:application, "FreeTime", :ios, "17.0")
widget = project.new_target(:app_extension, "FreeTimeWidget", :ios, "17.0")

main_group = project.main_group.new_group("FreeTime", "FreeTime")
app_group = main_group.new_group("App", "App")
shared_group = main_group.new_group("Shared", "Shared")
widget_group = main_group.new_group("Widget", "Widget")
assets_ref = main_group.new_file("Assets.xcassets")
app.resources_build_phase.add_file_reference(assets_ref)

Dir.glob(File.join(root, "FreeTime/App/*.swift")).sort.each do |path|
  ref = app_group.new_file(File.basename(path))
  app.source_build_phase.add_file_reference(ref)
end

shared_refs = Dir.glob(File.join(root, "FreeTime/Shared/*.swift")).sort.map do |path|
  shared_group.new_file(File.basename(path))
end
shared_refs.each do |ref|
  app.source_build_phase.add_file_reference(ref)
  widget.source_build_phase.add_file_reference(ref)
end

widget_ref = widget_group.new_file("FreeTimeWidget.swift")
widget.source_build_phase.add_file_reference(widget_ref)
widget_group.new_file("Info.plist")
widget_group.new_file("FreeTimeWidget.entitlements")
app_group.new_file("FreeTime.entitlements")

app.add_dependency(widget)
embed = app.new_copy_files_build_phase("Embed App Extensions")
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(widget.product_reference)

app.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.kensuke5704.FreeTime"
  config.build_settings["PRODUCT_NAME"] = "FreeTime"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["DEVELOPMENT_TEAM"] = "Y89MBS6Z86"
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "FreeTime/App/FreeTime.entitlements"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  config.build_settings["INFOPLIST_KEY_CFBundleDisplayName"] = "FreeTime"
  config.build_settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
  config.build_settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
  config.build_settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  config.build_settings["TARGETED_DEVICE_FAMILY"] = "1"
  config.build_settings["MARKETING_VERSION"] = "1.0"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
end

widget.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.kensuke5704.FreeTime.Widget"
  config.build_settings["PRODUCT_NAME"] = "FreeTimeWidget"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["DEVELOPMENT_TEAM"] = "Y89MBS6Z86"
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "FreeTime/Widget/FreeTimeWidget.entitlements"
  config.build_settings["INFOPLIST_FILE"] = "FreeTime/Widget/Info.plist"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
  config.build_settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  config.build_settings["SKIP_INSTALL"] = "YES"
  config.build_settings["TARGETED_DEVICE_FAMILY"] = "1"
  config.build_settings["MARKETING_VERSION"] = "1.0"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
end

project.build_configurations.each do |config|
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
end

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.save_as(project_path, "FreeTime", true)

project.save
puts project_path
