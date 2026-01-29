# Meditation Resources - Complete List

This document contains all manually curated meditation resources with YouTube video links for the Wellness Module.

## 📋 Meditation Resources Summary

### 🧘 Beginner & Short Guided Meditations

#### 1. 5-Minute Mindfulness Meditation
- **ID**: `med_001`
- **Category**: Beginner
- **Duration**: 5 minutes
- **Description**: A short and calming mindfulness session perfect for beginners. Learn to focus on the present moment and find peace in just 5 minutes.
- **YouTube Video ID**: `ssss7V1_eyA`
- **YouTube URL**: https://www.youtube.com/watch?v=ssss7V1_eyA

#### 2. 10-Minute Meditation for Beginners
- **ID**: `med_002`
- **Category**: Beginner
- **Duration**: 10 minutes
- **Description**: An easy entry-level mindfulness meditation designed for those new to meditation. Gentle guidance helps you relax and center yourself.
- **YouTube Video ID**: `U9YKY7fdwyg`
- **YouTube URL**: https://www.youtube.com/watch?v=U9YKY7fdwyg

#### 3. 10-Minute Stress & Anxiety Release Meditation
- **ID**: `med_003`
- **Category**: Anxiety
- **Duration**: 10 minutes
- **Description**: Release stress and anxiety with this guided meditation. Learn techniques to relax your body and calm your mind.
- **YouTube Video ID**: `H_uc-uQ3Nkc`
- **YouTube URL**: https://www.youtube.com/watch?v=H_uc-uQ3Nkc

#### 4. 10-Minute Mindfulness Calm Meditation
- **ID**: `med_004`
- **Category**: Focus
- **Duration**: 10 minutes
- **Description**: Focus on the present moment with this calming mindfulness meditation. Perfect for finding clarity and inner peace.
- **YouTube Video ID**: `y8KSid0WFwY`
- **YouTube URL**: https://www.youtube.com/watch?v=y8KSid0WFwY

---

### 🧘 Standard Daily Meditations (Useful for Focus & Peace)

#### 5. 10-Minute Daily Calm Guided Mindfulness
- **ID**: `med_005`
- **Category**: Focus
- **Duration**: 10 minutes
- **Description**: A daily mindfulness practice to bring calm and clarity to your day. Ideal for morning or evening routine.
- **YouTube Video ID**: `ZToicYcHIOU`
- **YouTube URL**: https://www.youtube.com/watch?v=ZToicYcHIOU

#### 6. 10-Minute Guided Meditation to Clear Your Mind
- **ID**: `med_006`
- **Category**: Focus
- **Duration**: 10 minutes
- **Description**: Clear mental clutter and find mental clarity with this guided meditation. Perfect for when you need to reset and refocus.
- **YouTube Video ID**: `uTN29kj7e-w`
- **YouTube URL**: https://www.youtube.com/watch?v=uTN29kj7e-w

---

### 🌙 Sleep & Anxiety Focused

#### 7. 20-Minute Sleep Meditation – Let Go of Anxiety
- **ID**: `med_007`
- **Category**: Sleep
- **Duration**: 20 minutes
- **Description**: A longer meditation session designed to help you let go of anxiety and prepare for restful sleep. Perfect for bedtime.
- **YouTube Video ID**: `QJreY2d32js`
- **YouTube URL**: https://www.youtube.com/watch?v=QJreY2d32js

#### 8. 20-Minute Guided Meditation for Anxiety & Sleep
- **ID**: `med_008`
- **Category**: Sleep
- **Duration**: 20 minutes
- **Description**: Comprehensive guided meditation addressing both anxiety relief and sleep preparation. Ideal for evening relaxation.
- **YouTube Video ID**: `Ar1WRzIsrO4`
- **YouTube URL**: https://www.youtube.com/watch?v=Ar1WRzIsrO4

#### 9. 10-Minute Meditation for Sleep & Relaxation
- **ID**: `med_009`
- **Category**: Sleep
- **Duration**: 10 minutes
- **Description**: Gentle meditation with rain sounds and calming guidance to help you relax and drift into peaceful sleep.
- **YouTube Video ID**: `bG3AcN-XOrw`
- **YouTube URL**: https://www.youtube.com/watch?v=bG3AcN-XOrw

---

## 📊 Category Breakdown

| Category | Count | Durations Available |
|----------|-------|---------------------|
| **Beginner** | 2 | 5 min, 10 min |
| **Anxiety** | 1 | 10 min |
| **Focus** | 3 | 10 min |
| **Sleep** | 3 | 10 min, 20 min |
| **Total** | **9** | 5 min, 10 min, 20 min |

---

## 🎯 Duration Breakdown

| Duration | Count | Categories |
|----------|-------|------------|
| **5 minutes** | 1 | Beginner |
| **10 minutes** | 6 | Beginner, Anxiety, Focus, Sleep |
| **20 minutes** | 2 | Sleep |

---

## ✅ Implementation Status

- ✅ All 9 meditation resources defined in `lib/data/meditation_resources.dart`
- ✅ Meditation player screen created (`lib/modules/user/screens/meditation_player_screen.dart`)
- ✅ Wellness screen updated to use meditation resources
- ✅ Category and duration filtering implemented
- ✅ Session tracking and favorites support added

---

## 📱 How It Works

1. **Admin adds meditation links** - Links are manually added during development (no admin UI needed)
2. **Users browse meditations** - Filter by category (Beginner, Anxiety, Focus, Sleep) and duration (5, 10, 20 min)
3. **Users play meditations** - Tap on a meditation to open the player screen
4. **YouTube integration** - Videos open in YouTube app/browser (link copied to clipboard)
5. **Session tracking** - System tracks completed sessions for personalized recommendations

---

## 🔧 Technical Details

- **Data Structure**: `lib/data/meditation_resources.dart`
- **Player Screen**: `lib/modules/user/screens/meditation_player_screen.dart`
- **Integration**: Wellness screen meditation tab uses these resources
- **Filtering**: By category and duration
- **Tracking**: Session counts stored in Firebase under `users/{username}/session_counts`

---

## 📝 Notes

- All videos are public YouTube content
- Videos are embedded/opened externally (not downloaded)
- Admin review recommended before publishing
- Content is manually curated for quality and appropriateness
