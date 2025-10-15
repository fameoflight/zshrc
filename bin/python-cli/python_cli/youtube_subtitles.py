"""
YouTube subtitle downloader with caching and parallel processing.

This module provides functionality to:
1. Extract channel video information to JSON
2. Download subtitles with progress tracking and parallelization
3. Cache downloaded content to avoid re-downloads
"""

import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Optional, Dict, Any
from urllib.parse import urlparse
import re

import yt_dlp
from rich.console import Console
from rich.progress import Progress, TaskID
from rich.table import Table

console = Console()


@dataclass
class VideoInfo:
    """Data class for video information."""
    id: str
    title: str
    url: str
    uploader: str
    upload_date: str
    duration: Optional[int] = None
    description: Optional[str] = None
    view_count: Optional[int] = None
    like_count: Optional[int] = None


class CacheManager:
    """Manages caching of downloaded subtitles and metadata."""

    def __init__(self, cache_dir: Optional[Path] = None):
        if cache_dir is None:
            cache_dir = Path.home() / ".config" / "zsh" / ".youtube-cache"

        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.metadata_dir = self.cache_dir / "metadata"
        self.subtitles_dir = self.cache_dir / "subtitles"

        self.metadata_dir.mkdir(exist_ok=True)
        self.subtitles_dir.mkdir(exist_ok=True)

    def get_channel_cache_path(self, channel_url: str) -> Path:
        """Get cache path for channel metadata."""
        channel_id = self._extract_channel_id(channel_url)
        return self.metadata_dir / f"{channel_id}.json"

    def get_subtitle_cache_path(self, video_id: str, lang: str = "en") -> Path:
        """Get cache path for video subtitle."""
        return self.subtitles_dir / f"{video_id}_{lang}.srt"

    def _extract_channel_id(self, channel_url: str) -> str:
        """Extract channel ID from URL."""
        # Handle different URL formats
        patterns = [
            r"@([^/]+)",
            r"channel/([^/]+)",
            r"c/([^/]+)",
            r"user/([^/]+)"
        ]

        for pattern in patterns:
            match = re.search(pattern, channel_url)
            if match:
                return match.group(1)

        # Fallback to hash of URL
        return str(abs(hash(channel_url)))

    def load_channel_info(self, channel_url: str) -> Optional[List[VideoInfo]]:
        """Load cached channel information."""
        cache_path = self.get_channel_cache_path(channel_url)

        if not cache_path.exists():
            return None

        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            return [VideoInfo(**video) for video in data]
        except Exception as e:
            console.print(f"[yellow]Warning: Failed to load cache: {e}[/yellow]")
            return None

    def save_channel_info(self, channel_url: str, videos: List[VideoInfo]) -> None:
        """Save channel information to cache."""
        cache_path = self.get_channel_cache_path(channel_url)

        try:
            with open(cache_path, 'w', encoding='utf-8') as f:
                json.dump([asdict(video) for video in videos], f, indent=2, ensure_ascii=False)
        except Exception as e:
            console.print(f"[yellow]Warning: Failed to save cache: {e}[/yellow]")

    def is_subtitle_cached(self, video_id: str, lang: str = "en") -> bool:
        """Check if subtitle is already cached."""
        return self.get_subtitle_cache_path(video_id, lang).exists()

    def get_cached_subtitle_path(self, video_id: str, lang: str = "en") -> Optional[Path]:
        """Get cached subtitle path if exists."""
        path = self.get_subtitle_cache_path(video_id, lang)
        return path if path.exists() else None


class VideoInfoExtractor:
    """Extracts video information from YouTube channels."""

    def __init__(self, cache_manager: Optional[CacheManager] = None):
        self.cache_manager = cache_manager or CacheManager()

    def extract_channel_videos(self, channel_url: str, force_refresh: bool = False) -> List[VideoInfo]:
        """Extract all video information from a YouTube channel."""

        # Auto-append /videos if not present
        if not channel_url.endswith('/videos'):
            channel_url = channel_url.rstrip('/') + '/videos'

        console.print(f"[bold blue]📺 Extracting channel videos...[/bold blue]")
        console.print(f"Channel: {channel_url}")

        # Try to load from cache first
        if not force_refresh:
            cached_videos = self.cache_manager.load_channel_info(channel_url)
            if cached_videos:
                console.print(f"[green]✅ Loaded {len(cached_videos)} videos from cache[/green]")
                return cached_videos

        # Use flat playlist extraction for speed - only get basic video info
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,  # Only get metadata, not video data
            'flat_playlist': True,  # Force flat playlist extraction
            'ignoreerrors': True,  # Skip unavailable videos
        }

        try:
            videos = []
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                with console.status("[bold green]Fetching channel information..."):
                    result = ydl.extract_info(channel_url, download=False)

                if not result:
                    console.print(f"[red]❌ No data found for channel: {channel_url}[/red]")
                    return []

                # Handle different result structures
                entries = []
                if result.get('_type') == 'playlist':
                    entries = result.get('entries', [])
                    console.print(f"[blue]Found playlist with {len(entries)} videos[/blue]")
                elif result.get('_type') == 'multiplaylist':
                    # Channel with multiple tabs - only use videos tab
                    console.print(f"[blue]Found multi-playlist channel[/blue]")
                    for playlist in result.get('entries', []):
                        if playlist and playlist.get('entries'):
                            playlist_title = playlist.get('title', '').lower()
                            # Only process videos, not shorts or streams
                            if 'video' in playlist_title or 'uploads' in playlist_title:
                                entries.extend(playlist.get('entries', []))
                                console.print(f"[blue]Using videos tab: {len(playlist.get('entries', []))} videos[/blue]")
                                break
                    # If no videos tab found, use the first playlist
                    if not entries and result.get('entries'):
                        first_playlist = result['entries'][0]
                        if first_playlist and first_playlist.get('entries'):
                            entries.extend(first_playlist.get('entries', []))
                            console.print(f"[blue]Using first playlist: {len(first_playlist.get('entries', []))} videos[/blue]")
                else:
                    # Single video
                    entries = [result] if result and result.get('id') else []
                    console.print(f"[blue]Found single video[/blue]")

                # Process entries quickly - skip None values
                valid_entries = [entry for entry in entries if entry and entry.get('id')]
                console.print(f"[blue]Processing {len(valid_entries)} video entries...[/blue]")

                # Basic info extraction with progress tracking
                with Progress() as progress:
                    task = progress.add_task("[green]Creating video list...", total=len(valid_entries))

                    for entry in valid_entries:
                        # Basic video info from flat extraction
                        video = VideoInfo(
                            id=entry.get('id', ''),
                            title=entry.get('title', 'Untitled Video'),
                            url=entry.get('url', f"https://www.youtube.com/watch?v={entry.get('id', '')}"),
                            uploader=entry.get('uploader') or result.get('uploader', 'Unknown Channel'),
                            upload_date=entry.get('upload_date', ''),
                            duration=entry.get('duration'),
                            description=None,  # Skip description for speed
                            view_count=entry.get('view_count'),
                            like_count=None  # Skip like count for speed
                        )
                        videos.append(video)
                        progress.advance(task)

                # Cache the results
                self.cache_manager.save_channel_info(channel_url, videos)

                console.print(f"[green]✅ Extracted {len(videos)} videos successfully[/green]")
                return videos

        except Exception as e:
            console.print(f"[red]❌ Error extracting channel info: {str(e)}[/red]")
            console.print(f"[yellow]💡 Try using the full channel URL: https://www.youtube.com/@channelname/videos[/yellow]")
            raise


class SubtitleDownloader:
    """Downloads subtitles for individual videos."""

    def __init__(self, cache_manager: Optional[CacheManager] = None):
        self.cache_manager = cache_manager or CacheManager()

    def download_subtitle(self, video: VideoInfo, lang: str = "en", output_dir: Optional[Path] = None) -> Optional[Path]:
        """Download subtitle for a single video."""
        # Check cache first
        cached_path = self.cache_manager.get_cached_subtitle_path(video.id, lang)
        if cached_path:
            # Copy from cache to output directory if needed
            if output_dir:
                output_dir = Path(output_dir)
                output_dir.mkdir(parents=True, exist_ok=True)
                target_path = output_dir / cached_path.name
                if not target_path.exists():
                    import shutil
                    shutil.copy2(cached_path, target_path)
                return target_path
            return cached_path

        # Set output directory
        if output_dir is None:
            output_dir = Path.home() / "Downloads" / self._sanitize_filename(video.uploader)
        else:
            output_dir = Path(output_dir)

        output_dir.mkdir(parents=True, exist_ok=True)

        ydl_opts = {
            'skip_download': True,
            'writesubtitles': True,
            'writeautomaticsub': True,
            'subtitleslangs': [lang],
            'subtitlesformat': 'srt',
            'quiet': True,
            'no_warnings': True,
            'outtmpl': str(output_dir / '%(title)s.%(ext)s'),
            'socket_timeout': 20,  # Faster timeout
            'retries': 1,  # Fewer retries for speed
            'ignoreerrors': True,  # Skip problematic videos
        }

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([video.url])

                # Find the downloaded subtitle file
                subtitle_path = self._find_subtitle_file(output_dir, video.title, lang)
                if subtitle_path:
                    # Copy to cache
                    cache_path = self.cache_manager.get_subtitle_cache_path(video.id, lang)
                    cache_path.parent.mkdir(parents=True, exist_ok=True)
                    import shutil
                    shutil.copy2(subtitle_path, cache_path)

                    return subtitle_path

        except Exception as e:
            # Don't print errors for common issues (members-only, private videos, etc.)
            if "members only" not in str(e).lower() and "private" not in str(e).lower():
                pass  # Silently ignore common issues

        return None

    def _find_subtitle_file(self, directory: Path, title: str, lang: str) -> Optional[Path]:
        """Find subtitle file in directory."""
        title_sanitized = self._sanitize_filename(title)

        # Look for various subtitle file patterns
        patterns = [
            f"{title_sanitized}.{lang}.srt",
            f"{title_sanitized}.{lang}.auto.srt",
            f"{title_sanitized}.srt",
        ]

        for pattern in patterns:
            file_path = directory / pattern
            if file_path.exists():
                return file_path

        # Fallback: search for any .srt file containing the title
        for file_path in directory.glob("*.srt"):
            if title_sanitized.lower() in file_path.stem.lower():
                return file_path

        return None

    def _sanitize_filename(self, filename: str) -> str:
        """Sanitize filename for safe file system usage."""
        # Remove invalid characters
        invalid_chars = r'[<>:"/\\|?*]'
        filename = re.sub(invalid_chars, '_', filename)

        # Remove extra whitespace and limit length
        filename = filename.strip()[:200]

        return filename


class ParallelSubtitleDownloader:
    """Manages parallel subtitle downloads."""

    def __init__(self, max_workers: int = 4, cache_manager: Optional[CacheManager] = None):
        self.max_workers = max_workers
        self.downloader = SubtitleDownloader(cache_manager)
        self.cache_manager = cache_manager or CacheManager()

    def download_subtitles(self, videos: List[VideoInfo], lang: str = "en",
                          output_dir: Optional[Path] = None, skip_cached: bool = True) -> Dict[str, Path]:
        """Download subtitles for multiple videos in parallel."""
        # Filter videos if skipping cached
        if skip_cached:
            uncached_videos = [v for v in videos if not self.cache_manager.is_subtitle_cached(v.id, lang)]
            cached_count = len(videos) - len(uncached_videos)

            if cached_count > 0:
                console.print(f"[green]📋 Skipping {cached_count} already downloaded subtitles[/green]")

            videos_to_download = uncached_videos
        else:
            videos_to_download = videos

        if not videos_to_download:
            console.print("[green]✅ All subtitles already downloaded![/green]")
            return {}

        console.print(f"[bold blue]⬇️  Downloading {len(videos_to_download)} subtitles...[/bold blue]")

        results = {}
        completed_count = 0

        with Progress() as progress:
            task = progress.add_task(
                f"[green]Downloading subtitles... (0/{len(videos_to_download)})",
                total=len(videos_to_download)
            )

            with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                # Submit all download tasks
                future_to_video = {
                    executor.submit(self.downloader.download_subtitle, video, lang, output_dir): video
                    for video in videos_to_download
                }

                # Process completed tasks
                for future in as_completed(future_to_video):
                    video = future_to_video[future]
                    completed_count += 1

                    try:
                        subtitle_path = future.result()
                        if subtitle_path:
                            results[video.id] = subtitle_path

                    except Exception as e:
                        console.print(f"[yellow]Error downloading '{video.title[:50]}...': {str(e)}[/yellow]")

                    # Update progress with count
                    progress.update(task, completed=completed_count,
                                   description=f"[green]Downloading subtitles... ({completed_count}/{len(videos_to_download)})")

        # Include cached subtitles in results
        if skip_cached:
            for video in videos:
                if video.id not in results:
                    cached_path = self.cache_manager.get_cached_subtitle_path(video.id, lang)
                    if cached_path:
                        results[video.id] = cached_path

        success_count = len(results)
        console.print(f"[green]✅ Downloaded {success_count} subtitles successfully[/green]")

        return results

    def export_video_info(self, videos: List[VideoInfo], output_path: Path) -> None:
        """Export video information to JSON file."""
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump([asdict(video) for video in videos], f, indent=2, ensure_ascii=False)

            console.print(f"[green]✅ Video info exported to {output_path}[/green]")

        except Exception as e:
            console.print(f"[red]❌ Error exporting video info: {str(e)}[/red]")
            raise


def display_channel_info(videos: List[VideoInfo]) -> None:
    """Display channel information in a nice table."""
    if not videos:
        console.print("[yellow]No videos found.[/yellow]")
        return

    table = Table(title="Channel Videos Information")
    table.add_column("Title", style="cyan", max_width=50)
    table.add_column("Upload Date", style="magenta")
    table.add_column("Duration", style="green")
    table.add_column("Views", style="yellow")

    for video in videos[:10]:  # Show first 10 videos
        # Handle duration formatting (could be int or float)
        if video.duration:
            duration_int = int(video.duration)
            duration_str = f"{duration_int//60}:{duration_int%60:02d}"
        else:
            duration_str = "N/A"

        views_str = f"{int(video.view_count):,}" if video.view_count else "N/A"

        table.add_row(
            video.title[:47] + "..." if len(video.title) > 50 else video.title,
            video.upload_date or "N/A",
            duration_str,
            views_str
        )

    console.print(table)

    if len(videos) > 10:
        console.print(f"[dim]... and {len(videos) - 10} more videos[/dim]")