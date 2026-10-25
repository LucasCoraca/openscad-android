// Android entry point for OpenSCAD: unpack share/openscad from the APK, give OpenSCAD a Unix-like environment in the
// app's private storage, then run OpenSCAD's own main (openscad_main, which starts the GUI).
//
//   <files>/openscad/bin                 OPENSCAD_APP_PATH: OpenSCAD looks for ../share/openscad from here
//   <files>/openscad/share/openscad      examples, libraries, fonts, color schemes, shaders, templates
//   <files>                              HOME; XDG_CONFIG_HOME is <files>/.config; OpenSCAD keeps backups and user
//                                        libraries in <files>/.local/share/OpenSCAD
//   <files>/Documents                    XDG_DOCUMENTS_DIR: where OpenSCAD saves by default
//   <cache>                              TMPDIR, XDG_CACHE_HOME (fontconfig cache)

#include "openscad.h"

#include <QtCore/QCoreApplication>
#include <QtWidgets/QAbstractScrollArea>
#include <QtWidgets/QApplication>
#include <QtWidgets/QDialog>
#include <QtGui/QScreen>
#include <QtWidgets/QProxyStyle>
#include <QtWidgets/QStyleOption>
#include <QtWidgets/QScroller>
#include <QtCore/QJniEnvironment>
#include <QtCore/QJniObject>
#include <QtCore/qresource.h>

#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/log.h>
#include <zip.h>

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

#include <unistd.h>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "openscad", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "openscad", __VA_ARGS__)

namespace fs = std::filesystem;

namespace {

std::string pathOf(const QJniObject& file)
{
  return file.callObjectMethod("getAbsolutePath", "()Ljava/lang/String;").toString().toStdString();
}

std::string readFile(const fs::path& p)
{
  std::ifstream in(p, std::ios::binary);
  return {std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>()};
}

std::string readEntry(zip_t *za, zip_int64_t index, zip_uint64_t size)
{
  std::string data(size, '\0');
  zip_file_t *zf = zip_fopen_index(za, index, 0);
  if (!zf) return {};
  const zip_int64_t n = zip_fread(zf, data.data(), size);
  zip_fclose(zf);
  if (n != zip_int64_t(size)) return {};
  return data;
}

// Unpack the openscad-share.zip asset into `dest` unless its .stamp matches the one there already.
bool unpackShare(const QJniObject& context, const fs::path& dest)
{
  QJniObject jassets = context.callObjectMethod("getAssets", "()Landroid/content/res/AssetManager;");
  AAssetManager *mgr = AAssetManager_fromJava(QJniEnvironment().jniEnv(), jassets.object());
  AAsset *asset = mgr ? AAssetManager_open(mgr, "openscad-share.zip", AASSET_MODE_BUFFER) : nullptr;
  if (!asset) {
    LOGE("asset openscad-share.zip is missing from the APK");
    return false;
  }
  const void *buf = AAsset_getBuffer(asset);
  const auto len = zip_uint64_t(AAsset_getLength64(asset));
  zip_error_t err;
  zip_error_init(&err);
  zip_source_t *src = buf ? zip_source_buffer_create(buf, len, 0, &err) : nullptr;
  zip_t *za = src ? zip_open_from_source(src, ZIP_RDONLY, &err) : nullptr;
  if (!za) {
    LOGE("openscad-share.zip: %s", zip_error_strerror(&err));
    if (src) zip_source_free(src);
    AAsset_close(asset);
    return false;
  }

  std::string stamp;
  zip_stat_t st;
  const zip_int64_t stampIndex = zip_name_locate(za, ".stamp", 0);
  if (stampIndex >= 0 && zip_stat_index(za, stampIndex, 0, &st) == 0) stamp = readEntry(za, stampIndex, st.size);
  const fs::path stampFile = dest / ".stamp";
  bool ok = true;
  if (!stamp.empty() && fs::exists(stampFile) && readFile(stampFile) == stamp) {
    LOGI("share/openscad up to date (%s)", stamp.c_str());
  } else {
    LOGI("unpacking share/openscad (%llu bytes) to %s", (unsigned long long)len, dest.c_str());
    std::error_code ec;
    fs::remove_all(dest, ec);
    fs::create_directories(dest, ec);
    const zip_int64_t n = zip_get_num_entries(za, 0);
    for (zip_int64_t i = 0; i < n && ok; ++i) {
      if (i == stampIndex || zip_stat_index(za, i, 0, &st) != 0) continue;
      const fs::path out = dest / st.name;
      if (std::string(st.name).back() == '/') {
        fs::create_directories(out, ec);
        continue;
      }
      fs::create_directories(out.parent_path(), ec);
      const std::string data = readEntry(za, i, st.size);
      std::ofstream f(out, std::ios::binary | std::ios::trunc);
      f.write(data.data(), std::streamsize(data.size()));
      ok = bool(f) && data.size() == st.size;
      if (!ok) LOGE("cannot unpack %s", st.name);
    }
    if (ok) std::ofstream(stampFile, std::ios::binary | std::ios::trunc) << stamp;  // last: an interrupted unpack is redone
  }
  zip_close(za);  // frees the source too
  AAsset_close(asset);
  return ok;
}

// Android drops stdout and stderr, where OpenSCAD reports e.g. shader compile errors (and the command line output):
// send their lines to logcat (tag openscad-stdio).
void forwardStdioToLogcat()
{
  int fds[2];
  if (pipe(fds) != 0) return;
  setvbuf(stdout, nullptr, _IOLBF, 0);
  setvbuf(stderr, nullptr, _IONBF, 0);
  dup2(fds[1], STDOUT_FILENO);
  dup2(fds[1], STDERR_FILENO);
  close(fds[1]);
  std::thread([fd = fds[0]] {
    std::string line;
    char buf[1024];
    ssize_t n;
    while ((n = read(fd, buf, sizeof buf)) > 0) {
      for (ssize_t i = 0; i < n; i++) {
        if (buf[i] != '\n') line += buf[i];
        if (buf[i] == '\n' || line.size() > 900) {
          __android_log_write(ANDROID_LOG_INFO, "openscad-stdio", line.c_str());
          line.clear();
        }
      }
    }
  }).detach();
}

void bootstrap()
{
  forwardStdioToLogcat();
  const QJniObject context = QNativeInterface::QAndroidApplication::context();
  const fs::path files = pathOf(context.callObjectMethod("getFilesDir", "()Ljava/io/File;"));
  const fs::path cache = pathOf(context.callObjectMethod("getCacheDir", "()Ljava/io/File;"));
  const fs::path root = files / "openscad";
  std::error_code ec;
  // OpenSCAD's own folders: documentsPath() is $HOME/.local/share (backups of unsaved files, user libraries there)
  for (const auto& d : {root / "bin", files / ".config", files / "Documents", files / ".local" / "share" / "OpenSCAD" / "backups",
                        files / ".local" / "share" / "OpenSCAD" / "libraries"})
    fs::create_directories(d, ec);
  unpackShare(context, root / "share" / "openscad");

  // the system language for gettext (OpenSCAD's own language setting, if any, goes into LANGUAGE)
  const QJniObject locale = QJniObject::callStaticObjectMethod("java/util/Locale", "getDefault", "()Ljava/util/Locale;");
  const std::string lang = locale.callObjectMethod("getLanguage", "()Ljava/lang/String;").toString().toStdString();
  const std::string country = locale.callObjectMethod("getCountry", "()Ljava/lang/String;").toString().toStdString();
  if (!lang.empty()) setenv("LANG", (lang + (country.empty() ? "" : "_" + country) + ".UTF-8").c_str(), 1);

  // Qt's widget backing store leaves stale pixels after partial repaints at fractional device pixel ratios (common on
  // phones: 2.625, 2.75, ...): use the nearest whole ratio
  setenv("QT_SCALE_FACTOR_ROUNDING_POLICY", "Round", 0);

  setenv("OPENSCAD_APP_PATH", (root / "bin").c_str(), 1);
  // development hook: KEY=VALUE lines (e.g. QT_LOGGING_RULES) in openscad-env in the app's external files folder,
  // /sdcard/Android/data/<package>/files, which `adb push` can write
  const QJniObject extFiles = context.callObjectMethod("getExternalFilesDir", "(Ljava/lang/String;)Ljava/io/File;", nullptr);
  std::ifstream envFile(extFiles.isValid() ? fs::path(pathOf(extFiles)) / "openscad-env" : fs::path());
  for (std::string line; std::getline(envFile, line);) {
    const auto eq = line.find('=');
    if (eq != std::string::npos && line[0] != '#') {
      setenv(line.substr(0, eq).c_str(), line.substr(eq + 1).c_str(), 1);
      LOGI("env %s", line.c_str());
    }
  }
  setenv("HOME", files.c_str(), 1);
  setenv("XDG_CONFIG_HOME", (files / ".config").c_str(), 1);
  setenv("XDG_DOCUMENTS_DIR", (files / "Documents").c_str(), 1);
  setenv("XDG_CACHE_HOME", cache.c_str(), 1);
  setenv("TMPDIR", cache.c_str(), 1);
}

}  // namespace

// Touch scrolling: every scroll area (editor, console, lists, trees, preferences pages) scrolls with a finger drag
// and flicks, as on Android, instead of starting a text selection. The scroller holds back the (touch-synthesized)
// mouse press until it knows the finger is not dragging, so a tap still clicks and a drag never selects.
class TouchScrolling : public QObject
{
public:
  using QObject::QObject;
  bool eventFilter(QObject *watched, QEvent *event) override
  {
    if (event->type() == QEvent::Polish) {
      if (auto *area = qobject_cast<QAbstractScrollArea *>(watched); area && area->viewport()) {
        QScroller::grabGesture(area->viewport(), QScroller::LeftMouseButtonGesture);
        QScrollerProperties props = QScroller::scroller(area->viewport())->scrollerProperties();
        props.setScrollMetric(QScrollerProperties::OvershootDragResistanceFactor, 0.0);
        props.setScrollMetric(QScrollerProperties::OvershootScrollDistanceFactor, 0.0);
        props.setScrollMetric(QScrollerProperties::HorizontalOvershootPolicy, QScrollerProperties::OvershootAlwaysOff);
        props.setScrollMetric(QScrollerProperties::VerticalOvershootPolicy, QScrollerProperties::OvershootAlwaysOff);
        QScroller::scroller(area->viewport())->setScrollerProperties(props);
      }
    }
    return false;
  }
};

void installTouchScrolling()
{
  if (qobject_cast<QApplication *>(QCoreApplication::instance()))
    qApp->installEventFilter(new TouchScrolling(qApp));
}
Q_COREAPP_STARTUP_FUNCTION(installTouchScrolling)

// Fusion's metrics are dpi-scaled against 96 dpi, but Android's logical dpi is based on 72, so they come out a
// quarter too small:
// - a menu item's check column is sized from those metrics, but painted at least 0.79 x the item height, so every
//   menu label was elided ("Para…tric"): reserve the column the painter actually uses;
// - small icons (menus, lists) shrank to a few pixels: keep them at least the 16 pixels Fusion means.
class AndroidStyle : public QProxyStyle
{
public:
  int pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const override
  {
    const int value = QProxyStyle::pixelMetric(metric, option, widget);
    return metric == PM_SmallIconSize ? std::max(value, 16) : value;
  }

  QSize sizeFromContents(ContentsType type, const QStyleOption *option, const QSize& size,
                         const QWidget *widget) const override
  {
    QSize result = QProxyStyle::sizeFromContents(type, option, size, widget);
    if (type == CT_MenuItem) {
      if (auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
          item && item->menuItemType != QStyleOptionMenuItem::Separator)
        result.rwidth() += result.height();
    }
    return result;
  }
};

// Dialogs sized for a desktop screen (Library Info, About) can be taller than the space above Android's taskbar,
// which hides their buttons: keep every dialog inside the screen's available area.
class FitDialogsToScreen : public QObject
{
public:
  using QObject::QObject;
  bool eventFilter(QObject *watched, QEvent *event) override
  {
    if (event->type() == QEvent::Show) {
      if (auto *dialog = qobject_cast<QDialog *>(watched); dialog && dialog->isWindow() && dialog->screen()) {
        const QRect available = dialog->screen()->availableGeometry();
        QRect geometry = dialog->geometry();
        if (!available.contains(geometry)) {
          geometry.setSize(geometry.size().boundedTo(available.size()));
          geometry.moveTop(std::clamp(geometry.top(), available.top(), available.bottom() + 1 - geometry.height()));
          geometry.moveLeft(std::clamp(geometry.left(), available.left(), available.right() + 1 - geometry.width()));
          dialog->setGeometry(geometry);
        }
      }
    }
    return false;
  }
};

void installStyle()
{
  if (!qobject_cast<QApplication *>(QCoreApplication::instance())) return;
  QApplication::setStyle(new AndroidStyle);
  qApp->installEventFilter(new FitDialogsToScreen(qApp));
}
Q_COREAPP_STARTUP_FUNCTION(installStyle)

int main(int argc, char **argv)
{
  // the qrc files of OpenSCADLibInternal, as in main_wrapper.cc
  Q_INIT_RESOURCE(common);
  Q_INIT_RESOURCE(icons_chokusen);
  Q_INIT_RESOURCE(icons_chokusen_dark);
  bootstrap();
  return openscad_main(argc, argv);
}
