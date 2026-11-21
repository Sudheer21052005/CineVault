import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch
import os

os.makedirs(r"D:\Projects\Sudheer-Prajapati-CineVault\diagrams", exist_ok=True)
out_dir = r"D:\Projects\Sudheer-Prajapati-CineVault\diagrams"

def draw_box(ax, x, y, w, h, text, title="", bg="#1E293B", border="#3B82F6", text_color="#FFFFFF", title_color="#93C5FD", fontsize=9, boxstyle="round,pad=0.3,rounding_size=0.15", lw=1.5):
    patch = FancyBboxPatch((x, y), w, h, boxstyle=boxstyle, facecolor=bg, edgecolor=border, linewidth=lw, zorder=2)
    ax.add_patch(patch)
    if title:
        ax.text(x + w/2, y + h - 0.22, title, ha="center", va="center", color=title_color, fontsize=fontsize+1.5, fontweight="bold", zorder=3)
        ax.text(x + w/2, y + (h - 0.28)/2, text, ha="center", va="center", color=text_color, fontsize=fontsize, zorder=3, linespacing=1.25)
    else:
        ax.text(x + w/2, y + h/2, text, ha="center", va="center", color=text_color, fontsize=fontsize, fontweight="bold", zorder=3, linespacing=1.2)

def draw_arrow(ax, x1, y1, x2, y2, color="#64748B", style="-|>", lw=1.8, label="", label_pos=(0.5, 0.5)):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle=style, color=color, lw=lw, mutation_scale=14), zorder=1)
    if label:
        lx = x1 + (x2 - x1) * label_pos[0]
        ly = y1 + (y2 - y1) * label_pos[1]
        ax.text(lx, ly, label, ha="center", va="center", fontsize=8, color="#475569", fontweight="bold",
                bbox=dict(boxstyle="square,pad=0.15", facecolor="#F8FAFC", edgecolor="none"), zorder=4)

# -------------------------------------------------------------
# DIAGRAM 1: SYSTEM ARCHITECTURE
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(12, 8.5), dpi=300)
ax.set_xlim(0, 12)
ax.set_ylim(0, 8.5)
ax.axis("off")
fig.patch.set_facecolor("#FFFFFF")

# Header
ax.text(6, 8.1, "Figure 4.1: CineVault Multi-Tier System Architecture", ha="center", va="center", fontsize=15, fontweight="bold", color="#0F172A")
ax.text(6, 7.75, "Presentation Layer (Flutter)  •  State & Logic  •  Network Service Layer  •  Hive NoSQL Local Storage", ha="center", va="center", fontsize=9.5, color="#64748B")

# Layers containers
# Layer 1: Presentation
p1 = FancyBboxPatch((0.4, 4.8), 11.2, 2.7, boxstyle="round,pad=0.2,rounding_size=0.1", facecolor="#F1F5F9", edgecolor="#CBD5E1", lw=1.5, ls="--", zorder=0)
ax.add_patch(p1)
ax.text(0.7, 7.3, "PRESENTATION LAYER (Material Design 3 Widgets)", fontsize=10, fontweight="bold", color="#334155")

draw_box(ax, 0.6, 6.35, 10.8, 0.75, "MainShell (Scaffold + IndexedStack + CompactBottomNav + PopScope Interceptor)", bg="#1E293B", border="#38BDF8", text_color="#F8FAFC", fontsize=10)

tabs = [
    ("Home Feed", "Hero Carousel\nAmbient Glow\nTrending Strip"),
    ("Now Playing", "Theatrical Grid\nLive Box Office\nRatings & Years"),
    ("TV Shows", "Airing Today\nPopular Series\nSeasons / Ep."),
    ("Deep Search", "Debounced Query\nGenre & Year\nRating Filter"),
    ("My Watchlist", "Plan / Watching / Done\nEdit & Review Sheet\nSorting Engine"),
    ("Analytics", "FL Chart Ring\nHeatmap Matrix\nAchievements")
]
for i, (t_title, t_sub) in enumerate(tabs):
    draw_box(ax, 0.6 + i*1.82, 5.0, 1.7, 1.15, t_sub, title=t_title, bg="#0F172A", border="#60A5FA", text_color="#E2E8F0", title_color="#93C5FD", fontsize=7.5)

# Layer 2: State & Business Logic
p2 = FancyBboxPatch((0.4, 3.0), 5.4, 1.5, boxstyle="round,pad=0.2,rounding_size=0.1", facecolor="#EFF6FF", edgecolor="#BFDBFE", lw=1.5, ls="--", zorder=0)
ax.add_patch(p2)
ax.text(0.7, 4.3, "STATE & DIARY LAYER", fontsize=10, fontweight="bold", color="#1E40AF")
draw_box(ax, 0.6, 3.2, 5.0, 0.95, "ChangeNotifier reactive state manager\nItem caching, sorting, status counts, heatmap & achievements", title="WatchlistProvider", bg="#1E3A8A", border="#3B82F6", text_color="#DBEAFE", title_color="#93C5FD", fontsize=8)

# Layer 3: Storage Layer
p3 = FancyBboxPatch((0.4, 0.5), 5.4, 2.2, boxstyle="round,pad=0.2,rounding_size=0.1", facecolor="#F0FDF4", edgecolor="#BBF7D0", lw=1.5, ls="--", zorder=0)
ax.add_patch(p3)
ax.text(0.7, 2.5, "LOCAL STORAGE LAYER (Hive NoSQL)", fontsize=10, fontweight="bold", color="#166534")
draw_box(ax, 0.6, 1.5, 5.0, 0.85, "Box<WatchlistItem>  •  TypeAdapter (TypeId: 1)\nCompound Key: '$type-$id' (Prevents Movie / TV collisions)", title="cinevault_watchlist Box", bg="#064E3B", border="#10B981", text_color="#D1FAE5", title_color="#6EE7B7", fontsize=8)
draw_box(ax, 0.6, 0.7, 5.0, 0.65, "Box<String>  •  Unlocked milestones: first-watch, 10-watched, etc.", title="cinevault_achievements Box", bg="#064E3B", border="#10B981", text_color="#D1FAE5", title_color="#6EE7B7", fontsize=7.5)

# Layer 4: Services Layer
p4 = FancyBboxPatch((6.2, 2.3), 5.4, 2.2, boxstyle="round,pad=0.2,rounding_size=0.1", facecolor="#FFFBEB", edgecolor="#FDE68A", lw=1.5, ls="--", zorder=0)
ax.add_patch(p4)
ax.text(6.5, 4.3, "NETWORK SERVICE LAYER (REST Client)", fontsize=10, fontweight="bold", color="#92400E")
draw_box(ax, 6.4, 2.5, 5.0, 1.65, "5-Minute In-Memory TTL Cache (LRU)\nIn-Flight Request Queue (Async Deduplication)\nShared http.Client + 3x Exponential Backoff Retry\nJSON Deserialization into Media models", title="TmdbService (Singleton)", bg="#78350F", border="#F59E0B", text_color="#FEF3C7", title_color="#FDE68A", fontsize=8)

# Layer 5: External Backend
p5 = FancyBboxPatch((6.2, 0.5), 5.4, 1.5, boxstyle="round,pad=0.2,rounding_size=0.1", facecolor="#FAF5FF", edgecolor="#E9D5FF", lw=1.5, ls="--", zorder=0)
ax.add_patch(p5)
ax.text(6.5, 1.8, "EXTERNAL DATA PROVIDER (Cloud)", fontsize=10, fontweight="bold", color="#6B21A8")
draw_box(ax, 6.4, 0.7, 5.0, 0.95, "api.themoviedb.org/3 (Trending, Movies, TV, Search)\nimage.tmdb.org/t/p/w500 (Poster & Backdrop CDN)", title="The Movie Database (TMDB v3 API)", bg="#581C87", border="#A855F7", text_color="#F3E8FF", title_color="#E9D5FF", fontsize=8)

# Connectors
draw_arrow(ax, 3.1, 4.8, 3.1, 4.15, color="#2563EB", lw=2, label="Read / Notify")
draw_arrow(ax, 3.1, 3.2, 3.1, 2.35, color="#059669", lw=2, label="Binary I/O")
draw_arrow(ax, 8.9, 4.8, 8.9, 4.15, color="#D97706", lw=2, label="Async Queries")
draw_arrow(ax, 8.9, 2.5, 8.9, 1.65, color="#9333EA", lw=2, label="HTTPS / JSON")

plt.tight_layout()
plt.savefig(os.path.join(out_dir, "Figure_4_1_System_Architecture.png"), dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
plt.close()

# -------------------------------------------------------------
# DIAGRAM 2: USE CASE DIAGRAM
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 8.5), dpi=300)
ax.set_xlim(0, 11)
ax.set_ylim(0, 8.5)
ax.axis("off")
fig.patch.set_facecolor("#FFFFFF")

ax.text(5.5, 8.1, "Figure 4.2: CineVault Use Case Diagram", ha="center", va="center", fontsize=15, fontweight="bold", color="#0F172A")
ax.text(5.5, 7.75, "Actor Interactions, Media Exploration, Diary Operations, and System Safeguards", ha="center", va="center", fontsize=9.5, color="#64748B")

# System Boundary Box
sys_box = FancyBboxPatch((3.0, 0.5), 7.6, 7.0, boxstyle="round,pad=0.2,rounding_size=0.15", facecolor="#F8FAFC", edgecolor="#0284C7", lw=2, zorder=0)
ax.add_patch(sys_box)
ax.text(6.8, 7.25, "CineVault Mobile Application Boundary", fontsize=11, fontweight="bold", color="#0369A1")

# Actor (Stick Figure)
ax.plot([1.2, 1.2], [4.4, 5.0], color="#1E293B", lw=3, zorder=3) # Body
ax.plot([0.8, 1.6], [4.8, 4.8], color="#1E293B", lw=3, zorder=3) # Arms
ax.plot([1.2, 0.8], [4.4, 3.7], color="#1E293B", lw=3, zorder=3) # Left Leg
ax.plot([1.2, 1.6], [4.4, 3.7], color="#1E293B", lw=3, zorder=3) # Right Leg
circle = plt.Circle((1.2, 5.4), 0.35, color="#1E293B", ec="#0284C7", lw=2, zorder=3)
ax.add_patch(circle)
ax.text(1.2, 3.3, "User / Cinephile", ha="center", va="center", fontsize=11, fontweight="bold", color="#0F172A")

# Use Cases
use_cases = [
    ("UC-1: Browse Featured & Trending Media", "Explore Hero Carousel with ambient lighting and weekly top movies", 6.4),
    ("UC-2: Explore Now-Playing & TV Catalogs", "View live theatrical releases, popular TV series and season metadata", 5.6),
    ("UC-3: Deep Search with Criteria Filters", "Debounced real-time keyword query filtered by genre, year, and score", 4.8),
    ("UC-4: Manage Personal Watchlist", "Add titles, categorize (Plan/Watching/Watched), sort, or delete records", 4.0),
    ("UC-5: Log Ratings, Personal Notes & Reviews", "Record 0.5 - 5.0 star scores, diary reviews, and date-watched stamps", 3.2),
    ("UC-6: Inspect Analytics & Activity Heatmap", "Visualize status ratios on FL Chart ring and monthly viewing frequency", 2.4),
    ("UC-7: Unlock Milestone Achievements", "Track progress towards First Watch, Marathon, and Explorer badges", 1.6),
    ("UC-8: Safe Back-Navigation & Exit Confirmation", "Intercept physical back button on home tab to confirm intentional exit", 0.8)
]

for title, desc, y_pos in use_cases:
    # draw ellipse/rounded box for use case
    uc_patch = FancyBboxPatch((3.4, y_pos - 0.28), 6.8, 0.62, boxstyle="round,pad=0.2,rounding_size=0.3",
                              facecolor="#FFFFFF", edgecolor="#38BDF8", lw=1.5, zorder=2)
    ax.add_patch(uc_patch)
    ax.text(6.8, y_pos + 0.08, title, ha="center", va="center", fontsize=8.8, fontweight="bold", color="#0F172A", zorder=3)
    ax.text(6.8, y_pos - 0.12, desc, ha="center", va="center", fontsize=7.5, color="#64748B", zorder=3)
    # line from actor
    ax.plot([1.6, 3.4], [4.6, y_pos], color="#94A3B8", lw=1.3, zorder=1)

plt.tight_layout()
plt.savefig(os.path.join(out_dir, "Figure_4_2_Use_Case_Diagram.png"), dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
plt.close()

# -------------------------------------------------------------
# DIAGRAM 3: DATABASE / NOSQL SCHEMA
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 8.5), dpi=300)
ax.set_xlim(0, 11)
ax.set_ylim(0, 8.5)
ax.axis("off")
fig.patch.set_facecolor("#FFFFFF")

ax.text(5.5, 8.1, "Figure 4.3: CineVault Hive NoSQL Schema & Binary Serialization", ha="center", va="center", fontsize=15, fontweight="bold", color="#0F172A")
ax.text(5.5, 7.75, "Low-Latency Key-Value Binary Storage with TypeAdapter Serialization (Box TypeId: 1)", ha="center", va="center", fontsize=9.5, color="#64748B")

# Main Box: cinevault_watchlist
draw_box(ax, 0.6, 1.2, 5.8, 6.2, "", title="Hive Box: cinevault_watchlist", bg="#0F172A", border="#38BDF8", title_color="#38BDF8", fontsize=9)

# Schema Table Header inside box
ax.text(0.9, 6.9, "FIELD INDEX", fontsize=7.5, fontweight="bold", color="#94A3B8")
ax.text(2.0, 6.9, "ATTRIBUTE", fontsize=7.5, fontweight="bold", color="#94A3B8")
ax.text(3.5, 6.9, "DART TYPE", fontsize=7.5, fontweight="bold", color="#94A3B8")
ax.text(4.7, 6.9, "DESCRIPTION", fontsize=7.5, fontweight="bold", color="#94A3B8")
ax.plot([0.8, 6.2], [6.75, 6.75], color="#334155", lw=1.2)

rows = [
    ("Index 0", "id", "int", "TMDB Media ID (e.g. 27205)"),
    ("Index 1", "type", "String", "'movie' or 'tv' discriminator"),
    ("Index 2", "title", "String", "Canonical media title"),
    ("Index 3", "posterPath", "String?", "TMDB relative image URI"),
    ("Index 4", "rating", "double", "Global TMDB vote average"),
    ("Index 5", "status", "String", "'planToWatch','watching','watched'"),
    ("Index 6", "userRating", "double?", "Personal score (0.5 to 5.0 ★)"),
    ("Index 7", "notes", "String", "User notes / theater memo"),
    ("Index 8", "addedAt", "int", "Unix timestamp (epoch ms)"),
    ("Index 9", "review", "String", "Personal written review text"),
    ("Index 10", "genres", "List<String>", "Assigned genre names"),
    ("Index 11", "dateWatched", "DateTime?", "Timestamp of completion")
]

for idx, (f_idx, f_name, f_type, f_desc) in enumerate(rows):
    y_r = 6.45 - idx * 0.42
    bg_c = "#1E293B" if idx % 2 == 0 else "#0F172A"
    rect = FancyBboxPatch((0.8, y_r - 0.15), 5.4, 0.35, boxstyle="square,pad=0.05", facecolor=bg_c, edgecolor="none")
    ax.add_patch(rect)
    ax.text(0.9, y_r, f_idx, fontsize=7, color="#38BDF8", va="center")
    ax.text(2.0, y_r, f_name, fontsize=7.5, fontweight="bold", color="#F8FAFC", va="center")
    ax.text(3.5, y_r, f_type, fontsize=7, color="#A7F3D0", va="center")
    ax.text(4.7, y_r, f_desc, fontsize=6.8, color="#CBD5E1", va="center")

# Right Column: Compound Key, TypeAdapter, Secondary Box, Enum
draw_box(ax, 6.8, 5.8, 3.8, 1.6, "Pattern: '$type-$id'\nExamples: 'movie-27205', 'tv-1396'\nGuarantees zero collision between movies and\nTV series that share identical integer IDs.", title="Compound Storage Key", bg="#1E1B4B", border="#6366F1", text_color="#E0E7FF", title_color="#A5B4FC", fontsize=8)

draw_box(ax, 6.8, 4.0, 3.8, 1.5, "Class: WatchlistItemAdapter (TypeId: 1)\nMethod: read(BinaryReader) -> WatchlistItem\nMethod: write(BinaryWriter, WatchlistItem) -> void\nProvides serialization-free low-latency binary I/O", title="TypeAdapter Mechanism", bg="#064E3B", border="#10B981", text_color="#ECFDF5", title_color="#6EE7B7", fontsize=8)

draw_box(ax, 6.8, 2.5, 3.8, 1.25, "Values: 'first-watch', 'ten-watched',\n'genre-explorer', 'movie-marathon', 'tv-explorer'\nStored separately to decouple profile from logs.", title="Box: cinevault_achievements", bg="#701A75", border="#D946EF", text_color="#FDF4FF", title_color="#F5D0FE", fontsize=8)

draw_box(ax, 6.8, 1.2, 3.8, 1.05, "planToWatch  -> 'Plan to Watch'\nwatching     -> 'Watching'\nwatched      -> 'Watched'", title="Enum: WatchStatus", bg="#451A03", border="#F59E0B", text_color="#FEF3C7", title_color="#FDE68A", fontsize=8)

# Connectors
draw_arrow(ax, 6.4, 4.75, 6.8, 4.75, color="#10B981", lw=2)
draw_arrow(ax, 6.4, 6.6, 6.8, 6.6, color="#6366F1", lw=2)

plt.tight_layout()
plt.savefig(os.path.join(out_dir, "Figure_4_3_Database_Design.png"), dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
plt.close()

# -------------------------------------------------------------
# DIAGRAM 4: APPLICATION FLOW & SCREEN NAVIGATION
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(12, 8.5), dpi=300)
ax.set_xlim(0, 12)
ax.set_ylim(0, 8.5)
ax.axis("off")
fig.patch.set_facecolor("#FFFFFF")

ax.text(6, 8.1, "Figure 4.4: Application Flow & Screen Navigation Lifecycle", ha="center", va="center", fontsize=15, fontweight="bold", color="#0F172A")
ax.text(6, 7.75, "Hierarchical Route Structure, Modal Lifecycle, and Android Back Navigation Safeguards", ha="center", va="center", fontsize=9.5, color="#64748B")

# Start
draw_box(ax, 4.6, 6.8, 2.8, 0.7, "Application Launch & Boot\n(dotenv load & Hive.initFlutter)", bg="#1E293B", border="#38BDF8", text_color="#FFFFFF", fontsize=8.5)

draw_arrow(ax, 6.0, 6.8, 6.0, 6.0, color="#64748B", lw=2)

# Main Shell
draw_box(ax, 3.5, 5.2, 5.0, 0.8, "MainShell (PopScope Wrapper)\nIndexedStack Root Router with CompactBottomNav", bg="#0284C7", border="#0284C7", text_color="#FFFFFF", fontsize=9.5)

# 6 Tabs
tabs_flow = [
    ("Home Tab (0)", "Hero Carousel\nGenres / Trending", 0.6),
    ("Now Playing (1)", "Box Office\nTheatrical Grid", 2.5),
    ("TV Shows (2)", "Popular Shows\nAiring Today", 4.4),
    ("Search (3)", "Debounce TMDB\nFilter Sheet", 6.3),
    ("Watchlist (4)", "Collection Hub\nStatus Filter Chips", 8.2),
    ("Stats (5)", "FL Chart Ring\nHeatmap / Badges", 10.1)
]

for t_name, t_desc, x_pos in tabs_flow:
    draw_arrow(ax, 6.0, 5.2, x_pos + 0.65, 4.2, color="#0284C7", lw=1.5)
    draw_box(ax, x_pos, 3.2, 1.3, 1.0, t_desc, title=t_name, bg="#1E293B", border="#38BDF8", text_color="#E2E8F0", title_color="#93C5FD", fontsize=7.5)

# Watchlist flow to modal
draw_arrow(ax, 8.85, 3.2, 8.85, 2.3, color="#10B981", lw=2, label="Tap Card", label_pos=(0.5, 0.5))
draw_box(ax, 7.3, 1.2, 3.1, 1.1, "Status Dropdown  •  0.5-5.0 Star Rating\nNotes Field  •  Personal Review Box\nWatched Date Picker  •  Save Changes", title="Watchlist Edit Bottom Sheet", bg="#064E3B", border="#10B981", text_color="#D1FAE5", title_color="#6EE7B7", fontsize=7.5)
draw_arrow(ax, 7.3, 1.75, 5.5, 1.75, color="#059669", lw=1.5, label="Persist to Hive")

# Back navigation flows
# Hardware back from subtabs
draw_box(ax, 0.6, 1.2, 4.8, 1.1, "If tab != 0: Intercept back press and switch to Home Tab\nIf tab == 0: Trigger AlertDialog('Exit CineVault?')\nStay: Dismiss Dialog   |   Exit: SystemNavigator.pop()", title="PopScope Physical Back-Key Guard", bg="#7F1D1D", border="#EF4444", text_color="#FEE2E2", title_color="#FCA5A5", fontsize=7.5)
draw_arrow(ax, 1.25, 3.2, 1.25, 2.3, color="#EF4444", lw=2, label="Back Key", label_pos=(0.5, 0.5))

plt.tight_layout()
plt.savefig(os.path.join(out_dir, "Figure_4_4_Application_Flow_Navigation.png"), dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
plt.close()

print("All 4 diagrams generated successfully!")
