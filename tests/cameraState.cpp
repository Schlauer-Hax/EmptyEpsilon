// Keep assertions enabled for Release builds too.
#undef NDEBUG
#include <cassert>
#include <array>
#include "camera.h"

glm::vec3 camera_position{0.0f};
float camera_yaw = 0.0f;
float camera_pitch = 0.0f;

static void expectCamera(const CameraState& expected)
{
    assert(camera_position == expected.position);
    assert(camera_yaw == expected.yaw);
    assert(camera_pitch == expected.pitch);
}

int main()
{
    const CameraState main_camera{{100.0f, 200.0f, 420.0f}, 35.0f, 30.0f};
    camera_position = main_camera.position;
    camera_yaw = main_camera.yaw;
    camera_pitch = main_camera.pitch;

    const std::array<CameraState, 4> sideviews{{
        {{10.0f, 20.0f, 0.0f}, -90.0f, 0.0f},
        {{30.0f, 40.0f, 0.0f}, -45.0f, 0.0f},
        {{50.0f, 60.0f, 0.0f}, 45.0f, 0.0f},
        {{70.0f, 80.0f, 0.0f}, 90.0f, 0.0f},
    }};

    // Five monitors over multiple frames, with a different draw order each frame.
    for (size_t frame = 0; frame < 20; ++frame)
    {
        {
            ScopedCamera main_view(std::nullopt);
            expectCamera(main_camera);
        }
        for (size_t i = 0; i < sideviews.size(); ++i)
        {
            const auto& sideview = sideviews[(i + frame) % sideviews.size()];
            {
                ScopedCamera side_view(sideview);
                expectCamera(sideview);
            }
            expectCamera(main_camera);
        }
    }

    // Nested draws and early returns must also restore their caller's camera.
    [&]() {
        ScopedCamera outer(sideviews[0]);
        {
            ScopedCamera inner(sideviews[1]);
            expectCamera(sideviews[1]);
        }
        expectCamera(sideviews[0]);
        return;
    }();
    expectCamera(main_camera);
}
