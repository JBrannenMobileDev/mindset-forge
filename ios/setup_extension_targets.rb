#!/usr/bin/env ruby
# Wires the iOS widget extension, watchOS app, and watch complication extension
# into Runner.xcodeproj. Idempotent: exits early if the targets already exist.
#
# Run from the ios/ directory:  ruby setup_extension_targets.rb

require 'xcodeproj'

PROJECT_PATH = 'Runner.xcodeproj'
TEAM = 'LBSV796ZRL'
APP_BUNDLE = 'com.mindsetforge.mindsetforge'
WIDGET_NAME = 'MindsetForgeWidget'
WATCH_NAME = 'MindsetForgeWatch'
WATCH_WIDGET_NAME = 'MindsetForgeWatchWidget'

project = Xcodeproj::Project.open(PROJECT_PATH)

existing = project.targets.map(&:name)
if existing.include?(WIDGET_NAME) || existing.include?(WATCH_NAME) || existing.include?(WATCH_WIDGET_NAME)
  puts "Extension targets already present (#{existing.join(', ')}). Nothing to do."
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

generated_xcconfig = project.files.find { |f| f.display_name == 'Generated.xcconfig' }

# ── Helpers ───────────────────────────────────────────────────────────────────

def set_on_all_configs(target, settings)
  target.build_configurations.each do |config|
    settings.each { |k, v| config.build_settings[k] = v }
  end
end

# new_target only creates Debug/Release; Flutter also archives with Profile.
def add_profile_config(project, target)
  release = target.build_configurations.find { |c| c.name == 'Release' }
  profile = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  profile.name = 'Profile'
  profile.build_settings = release.build_settings.dup
  profile.base_configuration_reference = release.base_configuration_reference
  target.build_configuration_list.build_configurations << profile
end

def use_generated_base_config(target, generated_xcconfig)
  return unless generated_xcconfig
  target.build_configurations.each do |config|
    config.base_configuration_reference = generated_xcconfig
  end
end

def group_with_files(project, group_name, paths)
  group = project.main_group.find_subpath(group_name, true)
  group.set_source_tree('SOURCE_ROOT')
  refs = {}
  paths.each do |path|
    ref = group.new_reference(path)
    refs[File.basename(path)] = ref
  end
  refs
end

def embed_phase(host, product_ref, name, spec, dst_path)
  phase = host.new_copy_files_build_phase(name)
  phase.symbol_dst_subfolder_spec = spec
  phase.dst_path = dst_path
  bf = phase.add_file_reference(product_ref)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  phase
end

def set_target_attributes(project, target)
  attrs = (project.root_object.attributes['TargetAttributes'] ||= {})
  attrs[target.uuid] = {
    'CreatedOnToolsVersion' => '15.0',
    'ProvisioningStyle' => 'Automatic',
  }
end

# ── 1. iOS widget extension ─────────────────────────────────────────────────

widget = project.new_target(:app_extension, WIDGET_NAME, :ios, '14.0')
widget_refs = group_with_files(project, WIDGET_NAME, [
  "#{WIDGET_NAME}/MindsetForgeWidget.swift",
  "#{WIDGET_NAME}/FocusWidgetViews.swift",
  "#{WIDGET_NAME}/WidgetPayload.swift",
  "#{WIDGET_NAME}/DesignTokens.swift",
  "#{WIDGET_NAME}/CompleteFocusIntent.swift",
  "#{WIDGET_NAME}/Info.plist",
  "#{WIDGET_NAME}/MindsetForgeWidget.entitlements",
])
widget_sources = %w[
  MindsetForgeWidget.swift FocusWidgetViews.swift WidgetPayload.swift
  DesignTokens.swift CompleteFocusIntent.swift
].map { |n| widget_refs[n] }
widget.add_file_references(widget_sources)

set_on_all_configs(widget, {
  'PRODUCT_BUNDLE_IDENTIFIER' => "#{APP_BUNDLE}.#{WIDGET_NAME}",
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'INFOPLIST_FILE' => "#{WIDGET_NAME}/Info.plist",
  'CODE_SIGN_ENTITLEMENTS' => "#{WIDGET_NAME}/#{WIDGET_NAME}.entitlements",
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => TEAM,
  'SWIFT_VERSION' => '5.0',
  'IPHONEOS_DEPLOYMENT_TARGET' => '14.0',
  'TARGETED_DEVICE_FAMILY' => '1,2',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'SKIP_INSTALL' => 'YES',
  'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
  'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS' => 'NO',
})
add_profile_config(project, widget)
use_generated_base_config(widget, generated_xcconfig)
set_target_attributes(project, widget)

# Shared App Intent compiles into the app target too (ForegroundContinuableIntent).
runner.add_file_references([widget_refs['CompleteFocusIntent.swift']])

# Runner depends on + embeds the widget extension.
runner.add_dependency(widget)
embed_phase(runner, widget.product_reference, 'Embed Foundation Extensions', :plug_ins, '')

# ── 2. watchOS app ────────────────────────────────────────────────────────────

watch = project.new_target(:application, WATCH_NAME, :watchos, '10.0')
watch_refs = group_with_files(project, WATCH_NAME, [
  "#{WATCH_NAME}/MindsetForgeWatchApp.swift",
  "#{WATCH_NAME}/WatchContentView.swift",
  "#{WATCH_NAME}/WatchConnectivityProvider.swift",
  "#{WATCH_NAME}/WatchPayload.swift",
  "#{WATCH_NAME}/WatchDesignTokens.swift",
  "#{WATCH_NAME}/Info.plist",
  "#{WATCH_NAME}/#{WATCH_NAME}.entitlements",
])
watch_sources = %w[
  MindsetForgeWatchApp.swift WatchContentView.swift
  WatchConnectivityProvider.swift WatchPayload.swift WatchDesignTokens.swift
].map { |n| watch_refs[n] }
watch.add_file_references(watch_sources)

set_on_all_configs(watch, {
  'PRODUCT_BUNDLE_IDENTIFIER' => "#{APP_BUNDLE}.watchkitapp",
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'INFOPLIST_FILE' => "#{WATCH_NAME}/Info.plist",
  'CODE_SIGN_ENTITLEMENTS' => "#{WATCH_NAME}/#{WATCH_NAME}.entitlements",
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => TEAM,
  'SWIFT_VERSION' => '5.0',
  'SDKROOT' => 'watchos',
  'WATCHOS_DEPLOYMENT_TARGET' => '10.0',
  'TARGETED_DEVICE_FAMILY' => '4',
  'SUPPORTED_PLATFORMS' => 'watchsimulator watchos',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'SKIP_INSTALL' => 'NO',
  'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO',
  'ENABLE_PREVIEWS' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks'],
})
add_profile_config(project, watch)
use_generated_base_config(watch, generated_xcconfig)
set_target_attributes(project, watch)

# ── 3. watch complication (widget) extension ──────────────────────────────────

watch_widget = project.new_target(:app_extension, WATCH_WIDGET_NAME, :watchos, '10.0')
watch_widget_refs = group_with_files(project, WATCH_WIDGET_NAME, [
  "#{WATCH_WIDGET_NAME}/WatchComplications.swift",
  "#{WATCH_WIDGET_NAME}/Info.plist",
  "#{WATCH_WIDGET_NAME}/#{WATCH_WIDGET_NAME}.entitlements",
])
# Reuse the watch app's shared model + tokens (multi-target membership).
watch_widget.add_file_references([
  watch_widget_refs['WatchComplications.swift'],
  watch_refs['WatchPayload.swift'],
  watch_refs['WatchDesignTokens.swift'],
])

set_on_all_configs(watch_widget, {
  'PRODUCT_BUNDLE_IDENTIFIER' => "#{APP_BUNDLE}.watchkitapp.#{WATCH_WIDGET_NAME}",
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'INFOPLIST_FILE' => "#{WATCH_WIDGET_NAME}/Info.plist",
  'CODE_SIGN_ENTITLEMENTS' => "#{WATCH_WIDGET_NAME}/#{WATCH_WIDGET_NAME}.entitlements",
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => TEAM,
  'SWIFT_VERSION' => '5.0',
  'SDKROOT' => 'watchos',
  'WATCHOS_DEPLOYMENT_TARGET' => '10.0',
  'TARGETED_DEVICE_FAMILY' => '4',
  'SUPPORTED_PLATFORMS' => 'watchsimulator watchos',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'SKIP_INSTALL' => 'YES',
  'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO',
  'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'],
})
add_profile_config(project, watch_widget)
use_generated_base_config(watch_widget, generated_xcconfig)
set_target_attributes(project, watch_widget)

# Watch app depends on + embeds the complication extension.
watch.add_dependency(watch_widget)
embed_phase(watch, watch_widget.product_reference, 'Embed Foundation Extensions', :plug_ins, '')

# iOS app depends on + embeds the watch app under the Watch/ folder.
runner.add_dependency(watch)
embed_phase(runner, watch.product_reference, 'Embed Watch Content', :products_directory, '$(CONTENTS_FOLDER_PATH)/Watch')

project.save
puts "Added targets: #{WIDGET_NAME}, #{WATCH_NAME}, #{WATCH_WIDGET_NAME}"
