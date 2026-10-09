#include "playerInfo.h"
#include "gameGlobalInfo.h"
#include "windowScreen.h"
#include "epsilonServer.h"
#include "main.h"
#include "multiplayer_client.h"
#include "components/collision.h"

#include "screenComponents/viewport3d.h"
#include "screenComponents/indicatorOverlays.h"
#include "screenComponents/shipDestroyedPopup.h"

WindowScreen::WindowScreen(RenderLayer* render_layer, float angle, uint8_t flags)
: GuiCanvas(render_layer), angle(angle)
{
    viewport = new GuiViewport3D(this, "VIEWPORT");
    viewport->setCamera(CameraState{});
    if (flags & flag_callsigns)
      viewport->showCallsigns();
    if (flags & flag_headings)
      viewport->showHeadings();
    if (flags & flag_spacedust)
      viewport->showSpacedust();
    viewport->setPosition(0, 0, sp::Alignment::TopLeft)->setSize(GuiElement::GuiSizeMax, GuiElement::GuiSizeMax);

    new GuiShipDestroyedPopup(this);

    new GuiIndicatorOverlays(this);
}

void WindowScreen::update(float delta)
{
    angle += (keys.helms_turn_right.getValue() - keys.helms_turn_left.getValue()) * 5.0f;

    if (keys.escape.getDown())
    {
        destroy();
        returnToShipSelection(getRenderLayer());
    }

    if (keys.pause.getDown())
        if (game_server && !gameGlobalInfo->getVictoryFaction()) engine->setGameSpeed(engine->getGameSpeed() > 0.0f ? 0.0f : 1.0f);

    if (game_client && game_client->getStatus() == GameClient::Disconnected)
    {
        destroy();
        disconnectFromServer();
        returnToMainMenu(getRenderLayer());
        return;
    }

    if (auto transform = my_spaceship.getComponent<sp::Transform>())
    {
        CameraState camera;
        camera.yaw = transform->getRotation() + angle;

        auto physics = my_spaceship.getComponent<sp::Physics>();
        auto radius = 300.0f;
        if (physics)
            radius = physics->getSize().x;
        auto position = transform->getPosition() + rotateVec2(glm::vec2(radius, 0), camera.yaw);

        camera.position = {position.x + 1.0f, position.y, 0.0f}; // small offset to prevent camera glitches on some models
        viewport->setCamera(camera);
    }
}
