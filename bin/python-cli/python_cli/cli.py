"""
Main CLI interface for python-cli.

Uses Typer for modern CLI with automatic help generation and type hints.
"""

import json
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table

from python_cli.coreml_inference import CoreMLInference
from python_cli.config import Config

app = typer.Typer(
    name="python-cli",
    help="Python CLI for PyTorch models with CoreML optimization",
    no_args_is_help=True,
)

console = Console()


def version_callback(value: bool):
    """Show version and exit."""
    if value:
        from python_cli import __version__
        typer.echo(f"python-cli version {__version__}")
        raise typer.Exit()


@app.callback()
def main(
    version: Optional[bool] = typer.Option(
        None, "--version", "-v", callback=version_callback, help="Show version and exit"
    ),
):
    """Python CLI for PyTorch models with CoreML optimization."""
    pass


@app.command()
def upscale(
    input_path: str = typer.Argument(..., help="Input image path"),
    output_path: Optional[str] = typer.Option(
        None, help="Output image path (auto-generates if not provided)"),
    model: str = typer.Option(
        "RealESRGAN_x4plus", "--model", "-m", help="Model name to use"),
    list_models: bool = typer.Option(
        False, "--list-models", help="List available models and exit"),
):
    """
    Upscale an image using PyTorch models with CoreML optimization.

    Examples:
        python-cli upscale photo.jpg
        python-cli upscale photo.jpg --model RealESRGAN_4x
        python-cli upscale photo.jpg result.jpg --model RealESRGAN_x4plus
    """
    if list_models:
        _list_models()
        return

    try:
        # Load configuration
        config = Config.load()

        # Validate model exists
        if model not in config.models:
            console.print(f"[red]Model '{model}' not found.[/red]")
            console.print("Available models:")
            _list_models()
            raise typer.Exit(1)

        # Generate output path if not provided
        if not output_path:
            input_file = Path(input_path)
            output_path = str(input_file.parent /
                              f"{input_file.stem}_upscaled{input_file.suffix}")

        # Validate input file
        if not Path(input_path).exists():
            console.print(f"[red]Input file not found: {input_path}[/red]")
            raise typer.Exit(1)

        # Get model info
        model_info = config.models[model]
        model_path = model_info.get(
            "coreml_path") or model_info.get("pytorch_path")

        console.print(f"[bold]🤖 Image Upscaling[/bold]")
        console.print(f"Input: {input_path}")
        console.print(f"Output: {output_path}")
        console.print(f"Model: {model}")
        console.print(
            f"Type: {'CoreML' if model_path.endswith('.mlmodel') else 'PyTorch'}")
        console.print()

        inference = CoreMLInference(model_path)

        inference.upscale_image(input_path, output_path)

        console.print(f"[green]✅ Upscaling completed successfully![/green]")
        console.print(f"Result saved to: {output_path}")

    except Exception as e:
        console.print(f"[red]❌ Error: {str(e)}[/red]")
        raise typer.Exit(1)


@app.command()
def models():
    """List available models."""
    _list_models()


def _list_models():
    """Internal function to list available models."""
    try:
        config = Config.load()

        if not config.models:
            console.print(
                "[yellow]No models found. Run 'make pytorch-setup' first.[/yellow]")
            return

        table = Table(title="Available Models")
        table.add_column("Model", style="cyan", no_wrap=True)
        table.add_column("Type", style="magenta")
        table.add_column("Status", style="green")

        for model_name, model_info in config.models.items():
            model_type = "CoreML" if model_info.get("coreml_path") and Path(
                model_info["coreml_path"]).exists() else "PyTorch"
            status = "✅ Default" if model_name == config.default_model else "  "
            table.add_row(model_name, model_type, status)

        console.print(table)
        console.print(f"\nDefault model: [bold]{config.default_model}[/bold]")

    except Exception as e:
        console.print(f"[red]Error loading models: {str(e)}[/red]")


@app.command()
def config():
    """Show configuration information."""
    try:
        cfg = Config.load()

        console.print("[bold]🔧 Configuration[/bold]")
        console.print(f"Default model: {cfg.default_model}")
        console.print(f"PyTorch models: {cfg.paths['pytorch']}")
        console.print(f"CoreML models: {cfg.paths['apple_silicon']}")
        console.print(f"Updated: {cfg.updated_at}")
        console.print()

        _list_models()

    except Exception as e:
        console.print(f"[red]Error loading configuration: {str(e)}[/red]")


if __name__ == "__main__":
    app()
