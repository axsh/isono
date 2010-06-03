
require 'isono'

raise "Please set ENV['RESOURCE_MANIFEST']" if ENV['RESOURCE_MANIFEST'].nil? || ENV['RESOURCE_MANIFEST'] == ''

$manifest = Isono::ResourceManifest.load(ENV['RESOURCE_MANIFEST'])
$instance_data = $manifest.instance_data
