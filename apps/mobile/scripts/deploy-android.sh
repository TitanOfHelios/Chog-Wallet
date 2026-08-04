#!/bin/bash

# Minimal Android release build: install deps, build the APK, copy it out.
# No fast-build/template-apk, no changelog/version.json, no 16KB check,
# no Sentry sourcemap prompts, no notifications, no remote upload.

script_dir="$( cd "$( dirname "$0"  )" && pwd  )"
project_dir=$(dirname $script_dir)

. $script_dir/fns.sh --source-only
. $script_dir/turbo-build/_fns.sh --source-only

export BUILD_TARGET_PLATFORM="android";
export RABBY_MOBILE_BUILD_ENV="regression";
check_build_params;

cd $project_dir;

deployment_local_dir="$script_dir/deployments/android"
rm -rf $deployment_local_dir && mkdir -p $deployment_local_dir;

prepare_android_build_artifacts() {
  turbo_prepare_js_dependencies || return $?

  ensure_inpage_bridge_assets || return $?

  yarn check-nodeengines &&
    yarn ../mobile-local-pages make-theme &&
    yarn ../mobile-local-pages build --mode android &&
    yarn react-native-asset &&
    sh ./scripts/fns.sh reset_builtin_assets &&
    yarn buildworker:prod:android
}

echo "[deploy-android] preparing build artifacts..."
prepare_android_build_artifacts || exit $?

echo "[deploy-android] building APK with gradle..."
if [ "$buildchannel" == "selfhost-reg" ]; then
  bash $project_dir/android/build.sh buildRegApk
  android_export_target="$project_dir/android/app/build/outputs/apk/regression/release/app-regression-release.apk"
  apk_name="rabby-mobile-regression.apk"
else
  bash $project_dir/android/build.sh buildApk
  android_export_target="$project_dir/android/app/build/outputs/apk/release/app-release.apk"
  apk_name="rabby-mobile.apk"
fi

if [ ! -f $android_export_target ]; then
  echo "[deploy-android] ⚠️ build failed! '$android_export_target' does not exist."
  exit 1
fi

cp $android_export_target $deployment_local_dir/$apk_name

echo ""
echo "[deploy-android] APK ready at: $deployment_local_dir/$apk_name"
echo "[deploy-android] finished."
