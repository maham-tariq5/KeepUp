# KeepUp
KeepUp is a Flutter-based running app that gamifies your workouts by turning your run into a survival-style experience. The app motivates you to maintain your target pace with real-time feedback, creepy music, and scary monster mechanics, making your runs both fun and intense.


# Features 

- **Set Goals:** Choose your target pace (min/km) and run duration.  
- **Dynamic Motivation:** If your pace drops below the goal, creepy music plays in your headphones to push you to speed up.  
- **Monster Threat:** Fail to return to your goal pace within a grace period, and virtual monsters "catch" you—ending your run.  
- **Detailed Stats:** Track your performance with average pace, best pace, and pace samples collected during the run.  
- **Custom Avatars:** Select running avatars to personalize your experience.  
- **Map Tracking:** Real-time map updates show your current location and route.  
- **Pause & Resume:** Automatic pause detection and manual control for flexible running sessions.  

## Technical Overview

- **Flutter:** Frontend app framework for cross-platform UI.
- **Geolocator:** Real-time GPS tracking with smoothing and accuracy filtering.
- **Pace Smoother:** Reduces noisy pace readings to give a stable and responsive pace display.
- **AudioPlayer:** Plays looping scary music when your pace drops.
- **Hive:** Local storage for run stats and profile data.
- **Flutter Map + LatLong2:** Shows real-time location on a map with animated avatar sprites.

## Authors and acknowledgment
- **Maleyha Fatima**
- **Maham Tariq**
- **Mariam Al Fahed**
- **Arseny Matveev**
  


