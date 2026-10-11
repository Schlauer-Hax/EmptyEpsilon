// Keep assertions enabled for Release builds too.
#undef NDEBUG
#include <cassert>
#include "gui/gui2_canvas.h"
#include "gui/gui2_progressslider.h"
#include "gui/theme.h"
#include "resources.h"

int main(int, char**)
{
    new DirectoryResourceProvider("resources");
    assert(GuiTheme::loadTheme("default", "gui/default.theme.txt"));
    auto canvas_owner = std::make_unique<GuiCanvas>();
    auto& canvas = *canvas_owner;
    using Button = sp::io::Pointer::Button;
    int changes = 0;
    int resets = 0;
    float requested = 0.0f;
    auto slider = new GuiProgressSlider(&canvas, "", 0.0f, 3.0f, 1.0f,
        [&](float value) { requested = value; ++changes; },
        [&]() { requested = 1.0f; ++resets; });
    slider->setSize(300.0f, 30.0f);
    canvas.updateLayout({0, 0, 300, 30});

    assert(canvas.onPointerDown(Button::Left, {200, 15}, 0));
    assert(requested == 2.0f && changes == 1);
    canvas.onPointerDrag({300, 15}, 0);
    assert(requested == 3.0f && changes == 2);
    canvas.onPointerUp({300, 15}, 0);

    assert(canvas.onPointerDown(Button::Right, {50, 15}, 0));
    assert(requested == 1.0f && resets == 1 && changes == 2);
    canvas.onPointerDrag({250, 15}, 0);
    canvas.onPointerUp({250, 15}, 0);
    assert(requested == 1.0f && resets == 1 && changes == 2);

    // Reset the request even when the displayed current level is already 100%.
    slider->setValue(1.0f);
    assert(canvas.onPointerDown(Button::Right, {290, 15}, 0));
    canvas.onPointerUp({290, 15}, 0);
    assert(requested == 1.0f && resets == 2 && changes == 2);

    assert(canvas.onPointerDown(Button::Left, {0, 15}, 0));
    canvas.onPointerUp({0, 15}, 0);
    assert(requested == 0.0f && changes == 3);

    slider->disable();
    assert(!canvas.onPointerDown(Button::Right, {200, 15}, 0));
    assert(resets == 2);

    // The remaining-coolant bar has no reset action and keeps its usual behavior.
    auto ordinary = new GuiProgressSlider(&canvas, "", 0.0f, 10.0f, 0.0f,
        [&](float value) { requested = value; });
    ordinary->setSize(300.0f, 30.0f);
    canvas.updateLayout({0, 0, 300, 30});
    assert(canvas.onPointerDown(Button::Right, {150, 15}, 0));
    assert(requested == 5.0f);
    canvas.onPointerDrag({300, 15}, 0);
    canvas.onPointerUp({300, 15}, 0);
    assert(requested == 10.0f);
}
