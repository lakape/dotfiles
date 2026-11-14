#pragma once

#include <effect/effect.h>
#include "windowappearance/sharedwindowsource.h"
#include <memory>

namespace KOS
{

class WindowAppearanceManager;
namespace WindowAppearance { class ContinuousClip; }

// Simple KWin effect that owns the unified window appearance:
// corner rounding, the frame band and outline around every managed window,
// and the dynamic stacked shadow.
class BridgeEffect final : public KWin::Effect, public SharedWindowSource
{
    Q_OBJECT
    Q_INTERFACES(KOS::SharedWindowSource)

public:
    BridgeEffect();
    ~BridgeEffect() override;

    void reconfigure(ReconfigureFlags flags) override;
    bool isActive() const override;
    int requestedEffectChainPosition() const override { return 100; }

    void prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *window,
                        KWin::WindowPrePaintData &data
#ifdef KOS_KWIN_PAINT_TIME_API
                        , std::chrono::milliseconds presentTime
#endif
                        ) override;

#ifdef KOS_KWIN_PAINT_RESULT_API
    bool
#else
    void
#endif
    drawWindow(const KWin::RenderTarget &renderTarget,
                    const KWin::RenderViewport &viewport,
                    KWin::EffectWindow *window, int mask,
                    const KWin::Region &deviceRegion,
                    KWin::WindowPaintData &data) override;

    bool drawSharedWindow(const KWin::RenderTarget &, const KWin::RenderViewport &,
                          KWin::EffectWindow *, int, const KWin::Region &,
                          KWin::WindowPaintData &, const WindowSourceMorph &) override;

private:
    std::unique_ptr<WindowAppearanceManager> m_appearance;
    std::unique_ptr<WindowAppearance::ContinuousClip> m_continuousClip;
    KWin::EffectWindow *m_lastActive = nullptr;
};

} // namespace KOS
