#!/usr/bin/env ruby
# Regenerate the checked-in Xcode project after adding app/UI-test source files.
# Uses the host's xcodeproj gem; runtime media must be hydrated with Git LFS.
require 'pathname'

root = File.expand_path('..', __dir__)
# Check before creating/replacing the project, even when xcodeproj is not installed.
unless system('/usr/bin/python3', '-B', File.join(__dir__, 'check_runtime_assets.py'), '--root', root)
  abort 'Runtime asset preflight failed; the Xcode project was not changed.'
end
require 'xcodeproj'

project_path = File.join(root, 'CatLife.xcodeproj')
project = Xcodeproj::Project.new(project_path)
project.root_object.compatibility_version = 'Xcode 14.0'
project.root_object.development_region = 'zh_CN'
project.root_object.known_regions = ['zh_CN', 'en', 'Base']

app = project.new_target(:application, 'CatLife', :ios, '17.0')
preflight = app.new_shell_script_build_phase('Check Runtime Assets')
preflight.shell_path = '/bin/sh'
preflight.shell_script = '/usr/bin/python3 -B "$SRCROOT/scripts/check_runtime_assets.py" --root "$SRCROOT"'
preflight.input_paths = ['$(SRCROOT)/scripts/check_runtime_assets.py', '$(SRCROOT)/scripts/runtime_assets.json',
                         '$(SRCROOT)/scripts/runtime_assets.xcfilelist']
preflight.input_file_list_paths = ['$(SRCROOT)/scripts/runtime_assets.xcfilelist']
preflight.always_out_of_date = '1'
preflight.show_env_vars_in_log = '0'
app.build_phases.delete(preflight)
app.build_phases.unshift(preflight)
app_group = project.main_group.new_group('CatLife', 'CatLife')
Dir.glob(File.join(root, 'CatLife', '**', '*.swift')).sort.each do |file|
  relative = Pathname.new(file).relative_path_from(Pathname.new(File.join(root, 'CatLife'))).to_s
  app.source_build_phase.add_file_reference(app_group.new_file(relative))
end
app.resources_build_phase.add_file_reference(app_group.new_file('Assets.xcassets'))
audio_folder = app_group.new_file('Audio')
audio_folder.last_known_file_type = 'folder'
app.resources_build_phase.add_file_reference(audio_folder)
app_group.new_file('Info.plist')

package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = 'CatGameCore'
project.root_object.package_references << package
dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dependency.package = package
dependency.product_name = 'CatGameCore'
app.package_product_dependencies << dependency
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = dependency
app.frameworks_build_phase.files << build_file

app.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.stationcat.catlife.native',
    'PRODUCT_NAME' => 'CatLife',
    'INFOPLIST_FILE' => 'CatLife/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'SWIFT_VERSION' => '6.0',
    'SWIFT_STRICT_CONCURRENCY' => 'complete',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SUPPORTED_PLATFORMS' => 'iphoneos iphonesimulator',
    'CODE_SIGN_STYLE' => 'Automatic',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES',
    'ENABLE_PREVIEWS' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'NO',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon'
  })
end

ui_tests = project.new_target(:ui_test_bundle, 'CatLifeUITests', :ios, '17.0')
ui_tests.add_dependency(app)
test_group = project.main_group.new_group('CatLifeUITests', 'CatLifeUITests')
Dir.glob(File.join(root, 'CatLifeUITests', '*.swift')).sort.each do |file|
  ui_tests.source_build_phase.add_file_reference(test_group.new_file(File.basename(file)))
end
ui_tests.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.stationcat.catlife.native.uitests',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'TEST_TARGET_NAME' => 'CatLife',
    'SWIFT_VERSION' => '6.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'CODE_SIGN_STYLE' => 'Automatic'
  })
end

unit_tests = project.new_target(:unit_test_bundle, 'CatLifeTests', :ios, '17.0')
unit_tests.add_dependency(app)
unit_group = project.main_group.new_group('CatLifeTests', 'CatLifeTests')
Dir.glob(File.join(root, 'CatLifeTests', '*.swift')).sort.each do |file|
  unit_tests.source_build_phase.add_file_reference(unit_group.new_file(File.basename(file)))
end
unit_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
unit_dependency.package = package
unit_dependency.product_name = 'CatGameCore'
unit_tests.package_product_dependencies << unit_dependency
unit_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
unit_build_file.product_ref = unit_dependency
unit_tests.frameworks_build_phase.files << unit_build_file
unit_tests.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.stationcat.catlife.native.tests',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'SWIFT_VERSION' => '6.0',
    'SWIFT_STRICT_CONCURRENCY' => 'complete',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'CODE_SIGN_STYLE' => 'Automatic',
    'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/CatLife.app/CatLife',
    'BUNDLE_LOADER' => '$(TEST_HOST)'
  })
end

project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '6.0'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(ui_tests)
scheme.set_launch_target(app)
scheme.add_test_target(ui_tests)
scheme.add_build_target(unit_tests)
scheme.add_test_target(unit_tests)
scheme.build_action.entries.each do |entry|
  next if entry.buildable_references.first.target_uuid == app.uuid
  entry.build_for_running = false
  entry.build_for_profiling = false
  entry.build_for_archiving = false
  entry.build_for_analyzing = false
end
scheme.save_as(project_path, 'CatLife', true)
puts "Generated #{project_path}"
