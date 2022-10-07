#include "analytics.h"

#include <QCryptographicHash>
#include <QDebug>
#include <QFile>
#include <QGuiApplication>
#include <QRandomGenerator>
#include <QScreen>
#include <QSettings>
#include <QSysInfo>
#include <QThread>
#include <QUuid>

#include <map>
#include <memory>
#include <string>

#include <countly/countly.hpp>

#include "httpmanager.h"
#include "httprequestactivity.h"
#include "settings.h"
#include "util.h"
#include "walletmanager.h"

static Analytics* g_analytics_instance{nullptr};

namespace {
inline constexpr char COUNTLY_HOST[] = "https://countly.blockstream.com";
inline constexpr char COUNTLY_TOR_ENDPOINT[] = "http://greciphd2z3eo6bpnvd6mctxgfs4sslx4hyvgoiew4suoxgoquzl72yd.onion";
inline constexpr char COUNTLY_APP_KEY_DEV[] = "cb8e449057253add71d2f9b65e5f66f73c073e63";
inline constexpr char COUNTLY_APP_KEY_REL[] = "351d316234a4a83169fecd7e760ef64bfd638d21";

std::map<std::string, std::string> QVariantMapToStdMap(const QVariantMap& in)
{
    std::map<std::string, std::string> out;
    for (auto i = in.begin(); i != in.end(); ++i) {
        out[i.key().toStdString()] = i.value().toString().toStdString();
    }
    return out;
}
}

Analytics::Analytics()
{
    Q_ASSERT(!g_analytics_instance);
    g_analytics_instance = this;

    auto os = QSysInfo::productType().toStdString();
    auto os_version = QSysInfo::productVersion().toStdString();
    auto device = GetHardwareModel().toStdString();
    auto screen_size = qGuiApp->primaryScreen()->size();
    auto resolution = QString("%1x%2").arg(screen_size.width()).arg(screen_size.height()).toStdString();
    auto& countly = cly::Countly::getInstance();
    countly.setLogger([](cly::Countly::LogLevel level, const std::string& message) {
        switch (level) {
        case cly::Countly::DEBUG:   qDebug() << QString::fromStdString(message); break;
        case cly::Countly::INFO:    qInfo() << QString::fromStdString(message); break;
        case cly::Countly::WARNING: qWarning() << QString::fromStdString(message); break;
        case cly::Countly::ERROR:   qCritical() << QString::fromStdString(message); break;
        case cly::Countly::FATAL:   qFatal("%s\n", message.c_str()); break;
        }
    });

    countly.setSha256([](const std::string& salted_data) {
        QCryptographicHash hash(QCryptographicHash::Sha256);
        hash.addData(QByteArray::fromStdString(salted_data));
        return hash.result().toStdString();
    });

    countly.setHTTPClient([](bool use_post, const std::string& path, const std::string& data) {
        cly::Countly::HTTPResponse res{false, {}};

        auto activity = new HttpRequestActivity;
        if (use_post) {
            activity->setMethod("POST");
            activity->addUrl(QString::fromStdString(COUNTLY_HOST + path));
            activity->addUrl(QString::fromStdString(COUNTLY_TOR_ENDPOINT + path));
            activity->setData(QString::fromStdString(data));
        } else {
            activity->setMethod("GET");
            activity->addUrl(QString::fromStdString(COUNTLY_HOST + path + "?" + data));
            activity->addUrl(QString::fromStdString(COUNTLY_TOR_ENDPOINT + path + "?" + data));
        }

        QEventLoop loop;
        QObject::connect(activity, &HttpRequestActivity::finished, &loop, &QEventLoop::quit);

        QTimer timer;
        timer.setInterval(100);
        timer.start();
        QObject::connect(&timer, &QTimer::timeout, &timer, [&] {
            if (!Analytics::instance()->isActive()) {
                timer.stop();
                loop.exit(1);
            }
        });

        HttpManager::instance()->exec(activity);

        if (!loop.exec()) {
            try {
                res.data = nlohmann::json::parse(activity->response().value("body").toString().toStdString());
                res.success = true;
            } catch (...) {
            }
        }

        return res;
    });

    countly.SetMetrics(os, os_version, device, resolution, "N/A", QCoreApplication::applicationVersion().toStdString());
    countly.SetMaxEventsPerMessage(40);
    countly.SetMinUpdatePeriod(10000);
    updateCustomUserDetails();
    check();

    connect(WalletManager::instance(), &WalletManager::changed, this, &Analytics::updateCustomUserDetails);
    connect(Settings::instance(), &Settings::analyticsChanged, this, &Analytics::check);
}

void Analytics::updateCustomUserDetails()
{
    std::map<std::string, std::string> user_details;
    user_details["total_wallets"] = std::to_string(WalletManager::instance()->size());
    cly::Countly::getInstance().setCustomUserDetails(user_details);
}

void Analytics::check()
{
    if (Settings::instance()->isAnalyticsEnabled()) {
        start();
    } else {
        stop();
    }
}

void Analytics::start()
{
    QString device_id;
    {
        QSettings analytics(GetDataFile("app", "analytics.ini"), QSettings::IniFormat);

        device_id = analytics.value("device_id").toString();
        if (device_id.isEmpty()) {
            device_id = QUuid::createUuid().toString(QUuid::WithoutBraces);
            analytics.setValue("device_id", device_id);
        }

        auto timestamp_offset = analytics.value("timestamp_offset").toInt();
        if (timestamp_offset == 0) {
            timestamp_offset = QRandomGenerator::global()->bounded(12 * 3600);
            analytics.setValue("timestamp_offset", timestamp_offset);
        }
        m_timestamp_offset = std::chrono::seconds(timestamp_offset);
    }

    const bool is_release = QStringLiteral("release") == QT_STRINGIFY(BUILD_TYPE);

    auto& countly = cly::Countly::getInstance();
    countly.setDeviceID(device_id.toStdString(), false);
    countly.setTimestampOffset(m_timestamp_offset);
    countly.start(is_release ? COUNTLY_APP_KEY_REL : COUNTLY_APP_KEY_DEV, COUNTLY_HOST, 443, true);
    m_active = true;
}

void Analytics::stop()
{
    auto& countly = cly::Countly::getInstance();
    m_active = false;
    countly.stop();

    if (!Settings::instance()->isAnalyticsEnabled()) {
        QFile::remove(GetDataFile("app", "analytics.ini"));
    }
}

Analytics::~Analytics()
{
    stop();
    g_analytics_instance = nullptr;
}

Analytics* Analytics::instance()
{
    Q_ASSERT(g_analytics_instance);
    return g_analytics_instance;
}

void Analytics::recordEvent(const QString& name)
{
    recordEvent(name, {});
}

void Analytics::recordEvent(const QString& name, const QVariantMap& segmentation)
{
    if (Settings::instance()->isAnalyticsEnabled()) {
        auto& countly = cly::Countly::getInstance();
        countly.RecordEvent(name.toStdString(), QVariantMapToStdMap(segmentation), 1);
    }
}

QString Analytics::pushView(const QString& name, const QVariantMap& segmentation)
{
    auto& countly = cly::Countly::getInstance();
    View view;
    view.name = name.toStdString();
    view.segmentation = QVariantMapToStdMap(segmentation);
    view.id = countly.views().openView(view.name, view.segmentation);
    m_views[view.id] = view;
    return QString::fromStdString(view.id);
}

void Analytics::popView(const QString& id)
{
    auto& countly = cly::Countly::getInstance();
    auto it = m_views.find(id.toStdString());
    if (it == m_views.end()) return;
    auto& view = it->second;
    countly.views().closeViewWithID(view.id);
    m_views.erase(it);
}

AnalyticsView::AnalyticsView(QObject* parent)
    : QObject(parent)
{
    connect(Settings::instance(), &Settings::analyticsChanged, this, &AnalyticsView::reset);
}

AnalyticsView::~AnalyticsView()
{
    close();
}

void AnalyticsView::setName(const QString& name)
{
    if (m_name == name) return;
    m_name = name;
    emit nameChanged();
    reset();
}

void AnalyticsView::setSegmentation(const QVariantMap& segmentation)
{
    if (m_segmentation == segmentation) return;
    m_segmentation = segmentation;
    emit segmentationChanged();
    reset();
}

void AnalyticsView::setActive(bool active)
{
    if (m_active == active) return;
    m_active = active;
    emit activeChanged();
    reset();
}

void AnalyticsView::reset()
{
    if (m_reset_timer > 0) killTimer(m_reset_timer);
    m_reset_timer = startTimer(1000);
}

void AnalyticsView::close()
{
    if (!m_id.isEmpty()) {
        Analytics::instance()->popView(m_id);
        m_id.clear();
    }
}

void AnalyticsView::open()
{
    if (Settings::instance()->isAnalyticsEnabled() && m_active && !m_name.isEmpty()) {
        m_id = Analytics::instance()->pushView(m_name, m_segmentation);
    }
}

void AnalyticsView::timerEvent(QTimerEvent* event)
{
    if (event->timerId() == m_reset_timer) {
        killTimer(m_reset_timer);
        m_reset_timer = 0;
        close();
        open();
    }
}

class AnalyticsEventPrivate {
public:
    QString name;
    QVariantMap segmentation;
    bool active{false};
    std::unique_ptr<cly::Event> event;
    int reset_timer{0};
};

AnalyticsEvent::AnalyticsEvent(QObject* parent)
    : QObject(parent)
    , d(new AnalyticsEventPrivate)
{
}

AnalyticsEvent::~AnalyticsEvent()
{
    stop();
}

QString AnalyticsEvent::name() const
{
    return d->name;
}

void AnalyticsEvent::setName(const QString& name)
{
    if (d->name == name) return;
    d->name = name;
    emit nameChanged();
    reset();
}

QVariantMap AnalyticsEvent::segmentation() const
{
    return d->segmentation;
}

void AnalyticsEvent::setSegmentation(const QVariantMap& segmentation)
{
    if (d->segmentation == segmentation) return;
    d->segmentation = segmentation;
    emit segmentationChanged();
}

bool AnalyticsEvent::active() const
{
    return d->active;
}

void AnalyticsEvent::setActive(bool active)
{
    if (d->active == active) return;
    d->active = active;
    emit activeChanged();
    reset();
}

void AnalyticsEvent::reset()
{
    if (d->reset_timer > 0) killTimer(d->reset_timer);
    d->reset_timer = startTimer(0);
}

void AnalyticsEvent::stop()
{
    if (d->event) {
        d->event.reset();
    }
}

void AnalyticsEvent::start()
{
    if (Settings::instance()->isAnalyticsEnabled() && d->active && !d->name.isEmpty()) {
        Q_ASSERT(!d->event);
        auto event = new cly::Event(d->name.toStdString());
        event->setTimestampOffset(Analytics::instance()->timestampOffset());
        event->startTimer();
        d->event.reset(event);
    }
}

void AnalyticsEvent::timerEvent(QTimerEvent* event)
{
    if (event->timerId() == d->reset_timer) {
        killTimer(d->reset_timer);
        d->reset_timer = 0;
        stop();
        start();
    }
}

void AnalyticsEvent::track()
{
    if (d->event) {
        d->event->stopTimer();
    } else {
        auto event = new cly::Event(d->name.toStdString());
        event->stamp(cly::Countly::getInstance().getTimestamp());
        d->event.reset(event);
    }
    std::map<std::string, std::string> out;
    for (auto i = d->segmentation.begin(); i != d->segmentation.end(); ++i) {
        d->event->addSegmentation(i.key().toStdString(), i.value().toString().toStdString());
    }
    cly::Countly::getInstance().addEvent(*d->event);
    stop();
    start();
}
