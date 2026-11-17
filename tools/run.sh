#!/bin/sh
cd "$(dirname "$0")/.." || exit 1

if [ -x ./tools/godot/godot ]; then
	exec ./tools/godot/godot --path . --display-driver x11
fi

if command -v godot >/dev/null 2>&1; then
	exec godot --path .
fi

echo "Нужен Godot 4.7 или новее: https://godotengine.org/download"
echo "Либо положи редактор в tools/godot/godot, либо установи команду godot."
exit 1
