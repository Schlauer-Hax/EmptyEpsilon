#pragma once

#include <glm/vec3.hpp>
#include <optional>

extern glm::vec3 camera_position;
extern float camera_yaw;
extern float camera_pitch;

struct CameraState
{
    glm::vec3 position{0.0f};
    float yaw = 0.0f;
    float pitch = 0.0f;
};

// Render systems still read the globals; an independent viewport only borrows them while drawing.
class ScopedCamera
{
    CameraState previous{camera_position, camera_yaw, camera_pitch};

public:
    explicit ScopedCamera(const std::optional<CameraState>& camera)
    {
        if (camera)
        {
            camera_position = camera->position;
            camera_yaw = camera->yaw;
            camera_pitch = camera->pitch;
        }
    }

    ~ScopedCamera()
    {
        camera_position = previous.position;
        camera_yaw = previous.yaw;
        camera_pitch = previous.pitch;
    }

    ScopedCamera(const ScopedCamera&) = delete;
    ScopedCamera& operator=(const ScopedCamera&) = delete;
};
