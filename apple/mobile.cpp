#include <SDL.h>
#include "mobile.h"
#include "preferenceManager.h"
#include "io/keybinding.h"

static string configuration_directory;

static void savePreferences()
{
    PreferencesManager::save(configuration_directory + "/options.ini");
    sp::io::Keybinding::saveKeybindings(configuration_directory + "/keybindings.json");
}

static int appEvents(void*, SDL_Event* event)
{
    if (event->type == SDL_APP_WILLENTERBACKGROUND || event->type == SDL_APP_TERMINATING)
        savePreferences();
    return 1;
}

void initAppleMobile(const string& configuration_path)
{
    // Restrict SDL's resizable controller as well as the app's Info.plist.
    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
    configuration_directory = configuration_path;
    // Existing settings screens also use EE_CONF_DIR when saving preferences.
    SDL_setenv("EE_CONF_DIR", configuration_path.c_str(), 1);
    SDL_DisableScreenSaver();
    SDL_AddEventWatch(appEvents, nullptr);
}
