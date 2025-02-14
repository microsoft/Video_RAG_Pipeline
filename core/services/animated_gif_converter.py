import aiohttp
import aiofiles
import os
from moviepy import VideoFileClip

class AnimatedGifConverter():

    def __init__(self, download_dir: str, client_session: aiohttp.ClientSession, min_width=320, min_height=240):
        self.download_dir = download_dir
        self.client_session = client_session

        self.min_width = min_width
        self.min_height = min_height

    async def download_and_convert_gif(self, url: str, gif_file_name: str) -> str:
        mp4_file_name = gif_file_name.replace(".gif", ".mp4")  # Define the MP4 file name
        mp4_full_path = os.path.join(self.download_dir, mp4_file_name)  # Full path for MP4

        gif_full_path = os.path.join(self.download_dir, gif_file_name)  # Temporary path for GIF

        await self.download_gif(url, gif_full_path)
        self.convert_gif_to_mp4(gif_full_path, mp4_full_path)

        return mp4_full_path
    
    async def download_gif(self, url: str, gif_full_path: str):
        """
        Asynchronously downloads a GIF from the specified URL and saves it to the given path.

        :param url: URL of the GIF to download
        :param save_path: Local file path to save the downloaded GIF
        """
        is_uploaded = True  # Sets the bool to uploaded

        async with self.client_session.get(url) as response:
            response.raise_for_status()
            async with aiofiles.open(gif_full_path, 'wb') as f:
                async for chunk in response.content.iter_chunked(8192):
                    await f.write(chunk)


    def convert_gif_to_mp4(self, gif_path: str, mp4_path: str):
        """
        Converts a GIF file to MP4 format, resizing if necessary.

        :param gif_path: Path to the input GIF file
        """
        with VideoFileClip(gif_path) as clip:   # Load the GIF as a video clip
            original_width, original_height = clip.size  # Get original dimensions

            # Check if resizing is needed based on minimum dimensions
            if original_width < self.min_width or original_height < self.min_height:
                scale_width = self.min_width / original_width
                scale_height = self.min_height / original_height
                scale_factor = max(scale_width, scale_height)  # Scale to meet both width and height requirements

                new_width = int(original_width * scale_factor)
                new_height = int(original_height * scale_factor)

                clip = clip.resize(new_size=(new_width, new_height))  # Resize the clip

            # Write the resized clip to an MP4 file without audio
            clip.write_videofile(mp4_path, codec="libx264", audio=False)
