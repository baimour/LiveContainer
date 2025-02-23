#!/bin/bash
if [ -d "$THEOS/lib/OpenSSL.framework" ]; then
	echo "OpenSSL.framework已存在于$THEOS/lib"
else
	echo "未找到OpenSSL.framework，正在下载..."

	curl -L "https://github.com/HAHALOSAH/OpenSSL-Swift/releases/download/3.1.5004/OpenSSL.xcframework.zip" -o "OpenSSL.xcframework.zip"

	unzip -q "OpenSSL.xcframework.zip" -d .

	mkdir -p "$THEOS/lib"
	mv "OpenSSL.xcframework/ios-arm64/OpenSSL.framework" "$THEOS/lib"

	rm -f "OpenSSL.xcframework.zip"
	rm -rf "OpenSSL.xcframework"

	echo "OpenSSL.framework has been installed to $THEOS/lib"
fi

if [ ! -d "./Resources/Frameworks/OpenSSL.framework" ]; then
    rsync -av --exclude 'Headers' "$THEOS/lib/OpenSSL.framework" "./Resources/Frameworks"
fi
