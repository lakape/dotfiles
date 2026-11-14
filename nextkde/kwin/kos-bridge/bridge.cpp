#include "bridge.h"
#ifdef KOS_KWIN_PAINT_RESULT_API
#include <opengl/eglcontext.h>
#endif
#include "windowappearance/windowappearance.h"

#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <core/renderviewport.h>
#include <window.h>

namespace KOS
{

namespace
{

bool appearanceEligible(const KWin::EffectWindow *window)
{
    if (!window || !window->isVisible() || !window->isManaged()) {
        return false;
    }
    if (!window->isNormalWindow() && !window->isDialog()) {
        return false;
    }
    if (window->isSkipSwitcher() || window->isSpecialWindow()) {
        return false;
    }
    if (window->isPopupWindow() || window->isPopupMenu()
        || window->isDropdownMenu() || window->isComboBox()
        || window->isMenu() || window->isTooltip() || window->isAppletPopup()
        || window->isOnScreenDisplay() || window->isNotification()
        || window->isCriticalNotification() || window->isSplash()
        || window->isUtility() || window->isDock() || window->isDesktop()
        || window->isDNDIcon()) {
        return false;
    }
    if (const KWin::Window *native = window->window();
        native && native->isInternal()) {
        return false;
    }
    const QString appId = window->windowClass();
    if (appId.contains(QStringLiteral("fcitx"), Qt::CaseInsensitive)
        || appId.contains(QStringLiteral("ibus"), Qt::CaseInsensitive)
        || appId.contains(QStringLiteral("inputmethod"), Qt::CaseInsensitive)) {
        return false;
    }
    return true;
}

} // namespace

BridgeEffect::BridgeEffect()
    : Effect()
    , m_appearance(std::make_unique<WindowAppearanceManager>())
    , m_continuousClip(std::make_unique<WindowAppearance::ContinuousClip>())
{
    KWin::effects->setProperty(SharedWindowSourceProperty,
        QVariant::fromValue(static_cast<QObject *>(this)));
    connect(KWin::effects, &KWin::EffectsHandler::windowDataChanged, this,
        [this](KWin::EffectWindow *window, int role) {
            if (role == DockSourceAnimationRole) {
                m_continuousClip->invalidate(window);
            }
        });
    connect(m_appearance.get(), &WindowAppearanceManager::configurationChanged,
            this, [this] { m_continuousClip->clear(); });

    connect(KWin::effects, &KWin::EffectsHandler::windowDeleted, this,
            [this](KWin::EffectWindow *window) {
                if (m_appearance) {
                    m_appearance->forget(window);
                }
                if (m_continuousClip) {
                    m_continuousClip->forget(window);
                }
                if (window == m_lastActive) {
                    m_lastActive = nullptr;
                }
            });

    connect(KWin::effects, &KWin::EffectsHandler::windowActivated, this,
            [this](KWin::EffectWindow *window) {
                if (m_lastActive && m_lastActive != window) {
                    m_lastActive->addRepaintFull();
                }
                m_lastActive = window;
                if (window) {
                    window->addRepaintFull();
                }
            });
}

BridgeEffect::~BridgeEffect()
{
    if (KWin::effects->property(SharedWindowSourceProperty).value<QObject *>() == this)
        KWin::effects->setProperty(SharedWindowSourceProperty, QVariant());
    disconnect(KWin::effects, nullptr, this, nullptr);
    disconnect(m_appearance.get(), nullptr, this, nullptr);
    m_appearance->restoreAll();
}

void BridgeEffect::reconfigure(ReconfigureFlags flags)
{
    Q_UNUSED(flags)
    if (m_appearance) {
        m_appearance->reconfigure();
    }
    if (m_continuousClip) {
        m_continuousClip->invalidateAll();
    }
    if (KWin::effects) {
        KWin::effects->addRepaintFull();
    }
}

bool BridgeEffect::isActive() const
{
    return true;
}

void BridgeEffect::prePaintWindow(KWin::RenderView *view,
                                 KWin::EffectWindow *window,
                                 KWin::WindowPrePaintData &data
#ifdef KOS_KWIN_PAINT_TIME_API
                                 , std::chrono::milliseconds presentTime
#endif
                                 )
{
    if (m_appearance && appearanceEligible(window)) {
        m_appearance->prepare(window, m_continuousClip->availableFor(window));
        const auto style = m_appearance->continuousStyle(window);
        if (m_continuousClip->configure(window, style)) {
            data.setTranslucent();
        } else if (style) {
            m_appearance->prepare(window, false);
        }
    } else if (m_continuousClip) {
        if (m_continuousClip->configure(window, m_appearance->continuousStyle(window))) {
            data.setTranslucent();
        }
    }
    Effect::prePaintWindow(view, window, data
#ifdef KOS_KWIN_PAINT_TIME_API
                           , presentTime
#endif
                           );
}

#ifdef KOS_KWIN_PAINT_RESULT_API
bool
#else
void
#endif
BridgeEffect::drawWindow(const KWin::RenderTarget &renderTarget,
                        const KWin::RenderViewport &viewport,
                        KWin::EffectWindow *window, int mask,
                        const KWin::Region &deviceRegion,
                        KWin::WindowPaintData &data)
{
    if (window->data(WindowSourceCaptureRole).toBool()) {
        return Effect::drawWindow(renderTarget, viewport, window, mask, deviceRegion, data);
    }
    const bool capture = window->data(LegacyWindowSourceCaptureRole).toBool();
    if (!capture && drawSharedWindow(renderTarget, viewport, window, mask, deviceRegion, data, {})) {
#ifdef KOS_KWIN_PAINT_RESULT_API
        return true;
#else
        return;
#endif
    }
#ifdef KOS_KWIN_PAINT_RESULT_API
    if (KWin::EglContext::currentContext() != KWin::effects->openglContext())
        return false;
    const bool painted = Effect::drawWindow(renderTarget, viewport, window, mask, deviceRegion, data);
    return painted;
#else
    Effect::drawWindow(renderTarget, viewport, window, mask, deviceRegion, data);
#endif
}

bool BridgeEffect::drawSharedWindow(const KWin::RenderTarget &target,
    const KWin::RenderViewport &viewport, KWin::EffectWindow *window, int mask,
    const KWin::Region &region, KWin::WindowPaintData &data, const WindowSourceMorph &morph)
{
    const auto style = m_appearance->continuousStyle(window);
    if (!style) return false;
    if (!m_continuousClip->configure(window, style)) {
        m_appearance->prepare(window, false);
        return false;
    }
    const bool result = m_continuousClip->paint(target, viewport, window, mask, region, data,
        *style, [this, window](const auto &sourceTarget, const auto &sourceViewport) -> bool {
            const QVariant previous = window->data(WindowSourceCaptureRole);
            window->setData(WindowSourceCaptureRole, true);
            KWin::WindowPaintData sourceData;
            sourceData.setOpacity(1.0);
#ifdef KOS_KWIN_PAINT_RESULT_API
            const bool painted =
                KWin::effects->drawWindow(sourceTarget, sourceViewport, window,
                    PAINT_WINDOW_TRANSFORMED | PAINT_WINDOW_TRANSLUCENT,
                    KWin::Region::infinite(), sourceData);
#else
            KWin::effects->drawWindow(sourceTarget, sourceViewport, window,
                PAINT_WINDOW_TRANSFORMED | PAINT_WINDOW_TRANSLUCENT,
                KWin::Region::infinite(), sourceData);
            const bool painted = true;
#endif
            window->setData(WindowSourceCaptureRole, previous);
            return painted;
        }, morph);

    if (result) {
        m_appearance->prepare(window, false);
    }
    return result;
}

} // namespace KOS
