
# Stop and exit on error
set -e

VERSION="0.6.0"

# Change dir to this scripts directory
script_dir=$(dirname $0)
cd $script_dir

# Generate plugin config
cd ..
sed 's/$VERSION/'$VERSION'/g' tools/plugin.template.cfg > addons/GodotAsyncLoader/plugin.cfg

# Create release
git commit -a -m "Release $VERSION"
git push

# Create and push tag
git tag v$VERSION -m "Release $VERSION"
git push --tags
