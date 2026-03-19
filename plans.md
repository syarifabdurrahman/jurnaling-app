I want to create Jurnaling app built with Flutter.

the big blueprint is like this:

1. People use journaling apps for clarity and peace of mind. The design must reflect that.

    - Aesthetic: Utilize a clean, glassmorphic UI. Translucent panels over soft, adaptive background gradients give a premium, calming, and highly modern feel.

    - Typography & Contrast: Prioritize a distraction-free writing environment with high-contrast text and elegant serif or sans-serif fonts.

    - Micro-interactions: Add subtle haptic feedback and smooth animations when an entry is saved or a mood is logged to make the habit feel instantly rewarding.

    - Privacy First: Incorporate a minimalist, secure vault screen for password login. Journaling requires absolute trust.

2. To build a scalable, performant, and intelligent app, this stack provides the best balance of speed and future-proofing:

    - Frontend: Flutter (Perfect for achieving smooth animations and custom UIs on Android, with the bonus of iOS readiness).

    - Backend & Auth: Supabase. It provides seamless authentication and a robust PostgreSQL database for syncing entries across devices.

    - Local Storage: Isar Database. Crucial for an offline-first experience so users can write even without the internet. It is blazing fast for Flutter.

    - AI Integration: OpenRouter. This allows you to easily plug in various LLMs for smart features (like summarizing entries or generating prompts) without being locked into a single provider.

    - State Management: Riverpod. It is modern, compile-safe, and excellent for handling complex data streams like real-time user input.

3. 
Step 1: The Core MVP (Focus: Usability)

    Biometric lock (Fingerprint/FaceID).

    Rich text editor (bold, italics, bullet points, image attachments).

    Offline-first saving with background cloud sync.

    Basic mood tagging (e.g., choosing an emoji or color for the day).

Step 2: Retention Features (Focus: Daily Habits)

    Adaptive Prompts: Daily changing questions tailored to the time of day to help users overcome writer's block.

    The Reflection Jar: A dedicated feature that surfaces random positive entries or insights from the past to encourage mindfulness and gratitude.

    Streaks & Stats: A beautifully visualized calendar showing writing streaks and mood fluctuations over the month.

Step 3: Growth & Viral Features (Focus: Downloads)

    Aesthetic Export: Allow users to turn a specific sentence from their journal into a beautifully formatted, high-contrast quote card to share on Instagram Stories or TikTok.

    AI Mood Insights: Use AI to generate a private, weekly summary of their mental well-being based on the tone of their writing.

==================================================================

1. Visual Identity & UI/UX (The Conversion Hook)
When users search for a journal, they are looking for a safe, calming, and premium space. If your UI looks cheap, they will bounce immediately, which kills your Play Store ranking.

Typography: Use a two-font system.

UI Elements (Buttons, Menus): Use a modern, clean Sans-Serif like Inter or Plus Jakarta Sans.

The Writing Experience: Use an elegant Serif font like Playfair Display or Lora. This makes the user's writing feel like a published book.

Color Palette: Default to a deep, OLED-friendly Dark Mode (e.g., almost black with subtle deep indigo or forest green gradients). It’s easier on the eyes for late-night journaling and looks incredibly sleek.

The Icon: This is your most important asset for organic downloads. It must be a minimalist, high-contrast design. Avoid literal pens and books. Think of a simple, abstract glowing shape (like a spark or a serene moon) against a dark background.

2. Strategic Ad Placement (Monetization without Churn)
Journaling is intimate. If a user opens the app to write about a bad day and sees a flashing banner ad for a mobile game at the bottom of the screen, they will uninstall it immediately.

NEVER put ads on the writing screen. * Native Ads in the Feed: If you have a scrolling list of past entries, insert a "Native Ad" every 5-7 entries. Design the ad container to perfectly match the glassmorphic style of your app so it feels seamless and non-intrusive.

Rewarded Video (The Best Approach): Introduce a "Premium for a Day" feature. Allow users to unlock premium fonts, custom themes, or an AI-generated weekly mood insight by voluntarily watching a single 30-second rewarded video ad. Users love this because it's their choice.

3. The "Zero-Marketing" Growth Engine
To get organic downloads, you need the Play Store algorithm to fall in love with your app. The algorithm cares about three things: Keyword relevance, Crash-free sessions, and Positive Review Velocity.

ASO Title & Subtitle: Do not just name your app "MyJournal." Name it strategically for search queries: "[Your App Name]: Minimal Diary & Mood" or "[Your App Name]: Secure Journal with Lock".

The 3-Day Review Trigger: Do not ask for a review on day one. Program the app to ask for a Play Store rating only immediately after the user completes a 3-day journaling streak and hits "Save." They are feeling accomplished and are much more likely to leave a 5-star review, which rockets you up the search rankings.

Built-in Viral Loops: Build an "Export to Story" feature. Let users highlight a single sentence from their journal and turn it into a beautiful, high-contrast image to save to their phone or post to Instagram/TikTok. Include a very tiny, elegant watermark at the bottom: "Reflected in [Your App Name]". Your users will become your marketing team.

==================================================================
1. The "Midnight & Lavender" PaletteThis color scheme is optimized for OLED screens, which saves battery and provides the high contrast that the Play Store algorithm favors in screenshots.
Element,Hex Code,Purpose
    Background,#0F0E17,Deepest charcoal (not pure black) for a softer look.
    Surface,#1A1A2E,Card backgrounds/Glassmorphic panels.
    Accent Primary,#A78BFA,"Lavender (Soft, calming, premium)."
    Accent Secondary,#2CB67D,"Emerald (Used for ""Save"" buttons or positive mood markers)."
    High Contrast Text,#FFFFFE,Primary titles and body text.
    Muted Text,#94A1B2,"Dates, subtitles, and secondary info."

2. Typography Strategy
    Headings/UI (Sans-Serif): Use GoogleFonts.plusJakartaSans(). It is modern, geometric, and very readable.

    The Journal Body (Serif): Use GoogleFonts.lora() or GoogleFonts.playfairDisplay(). A serif font makes the user's personal thoughts feel like a classic novel.

3.This structure uses a minimalist "Glassmorphic" approach. You’ll need the glassmorphism and google_fonts packages in your pubspec.yaml.

    // main_scaffold.dart
    Scaffold(
    backgroundColor: Color(0xFF0F0E17),
    body: CustomScrollView(
        slivers: [
        SliverAppBar(
            floating: true,
            backgroundColor: Colors.transparent,
            title: Text('My Reflections', 
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
            actions: [
            IconButton(icon: Icon(Icons.search, color: Colors.white), onPressed: () {}),
            ],
        ),
        SliverList(
            delegate: SliverChildBuilderDelegate(
            (context, index) {
                // Every 5th item is a Native Ad to maximize revenue without annoying users
                if (index != 0 && index % 5 == 0) {
                return NativeAdContainer(); 
                }
                return JournalCard(); // Your glassmorphic entry card
            },
            childCount: 20,
            ),
        ),
        ],
    ),
    floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFA78BFA),
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.pushNamed(context, '/write'),
    ),
    );

4. High-Conversion "Aesthetic" Details
    Glassmorphic Cards: Instead of solid colors, use a BackdropFilter with a slight blur ($10.0$) and a very thin, semi-transparent white border ($0.5$ opacity). This makes the app look like it’s made of frosted glass.Spacing (The 8pt Grid): Use generous padding. Never let text touch the edges of the screen. A $24.0$ horizontal padding on the writing screen makes the app feel "breathable."Micro-Animations: Use the animations package from the Flutter team for "Open Container" transitions. When a user taps a journal entry, it should physically expand to fill the screen rather than just snapping to a new page.

5.Ad Placement for Max Revenue
    To hit high revenue in the first month without driving users away:

    Native Ads: Integrated into the ListView of entries. Give them the same corner radius and padding as your journal cards.

    App Open Ad: Show a single high-quality ad when the app finishes its splash screen (only once every 4 hours).

    The "Export" Reward: If a user wants to export their entry as a high-resolution "Quote Card" for Instagram, offer to remove the watermark if they watch one 30-second Rewarded Video.

    ==========================================================

update theme:

    Element,Hex Code,Role
    Primary Accent,#FF7E54,"The ""Coral/Orange"" for active buttons and progress bars."
    Secondary Soft,#E2E8F0,For subtle card borders and dividers.
    Background,#F8F9FA,"An ""Off-White"" (Ivory) that feels more premium than pure white."
    Text Primary,#1E293B,A deep slate blue-gray for readability.

1. The "Vibe Code" (Design Principles)Organic Warmth: Notice there are no sharp 90-degree corners. The border radius is very high (around $28.0$ to $32.0$ for cards).Depth through Layering: Instead of using flat colors, use Stacking. In the first screen, the "How are you feeling" card sits on top of a photo, but it uses a blur effect (BackdropFilter) so the photo colors "bleed" through.Human-Centric Social Proof: The line "832,432 people are thriving today" is crucial. It’s not a "feature," it’s a psychological trigger. It makes the app feel like a community, not a tool.The "Coral" Pop: Use one—and only one—vibrant accent color (the Coral/Orange). This guides the eye immediately to the most important buttons (Home, Save, CTA).

A. Typography & Text Hierarchy
Do not use the default Flutter fonts. They scream "developer project."

Primary Font: Plus Jakarta Sans or Outfit (via Google Fonts).

The Trick: Use very heavy weights (FontWeight.w800) for headers and light weights (FontWeight.w400) with increased line height (height: 1.5) for the reflection text.

B. The Custom Layouts
Standard Flutter widgets won't cut it for these specific looks:

For Screen 1 (Hero Image): Use a Stack widget. The bottom layer is a ClipRRect containing the lavender photo. The top layer is a Positioned container with Glassmorphism.

For Screen 2 (Photo Grid): Build a "Mosaic" layout. Instead of a standard GridView, use a Row containing two Columns with different aspect ratios for the photos. This looks "journal-like" rather than "database-like."

For Screen 3 (Charts): Use the fl_chart package. To get that "Soft" look, set the isCurved: true property on the line chart and use a LinearGradient for the area underneath the line.

C. The Floating Navigation Pill
Most apps have a bar that touches the bottom of the screen. To look like the image:

Wrap your BottomNavigationBar in a Padding and a Container with a borderRadius.

Give it a FloatingActionButtonLocation.centerDocked feel, but keep it as a standalone widget on top of the body using a Stack.

B. The Mood Selector (Glassmorphic)
In your image, the "How are you feeling?" card uses a blur effect. In Flutter, use the BackdropFilter widget.

For the Emojis: Do not use standard Android emojis (they look dated). Use Fluent Emojis (Microsoft) or Apple Emojis by importing them as SVGs or PNGs. They look much more "lifestyle."

C. The "Multiphoto" Entry Card
Notice how the second screen uses a grid for photos. Use StaggeredGrid or a simple Row with two Columns for that "scrapbook" feel.