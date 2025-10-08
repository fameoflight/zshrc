"""
ESRGAN-specific PyTorch model implementations
Contains RRDBNet architecture and ESRGAN model loading functionality
"""

import torch
import math
from .utils import BaseImageInference


class ResidualDenseBlock(torch.nn.Module):
    def __init__(self, num_feat=64, num_grow_ch=32):
        super(ResidualDenseBlock, self).__init__()
        self.conv1 = torch.nn.Conv2d(num_feat, num_grow_ch, 3, 1, 1)
        self.conv2 = torch.nn.Conv2d(num_feat + num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv3 = torch.nn.Conv2d(num_feat + 2 * num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv4 = torch.nn.Conv2d(num_feat + 3 * num_grow_ch, num_grow_ch, 3, 1, 1)
        self.conv5 = torch.nn.Conv2d(num_feat + 4 * num_grow_ch, num_feat, 3, 1, 1)

        self.lrelu = torch.nn.LeakyReLU(negative_slope=0.2, inplace=True)

        # Initialization
        for m in [self.conv1, self.conv2, self.conv3, self.conv4, self.conv5]:
            if isinstance(m, torch.nn.Conv2d):
                torch.nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')

    def forward(self, x):
        x1 = self.lrelu(self.conv1(x))
        x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
        x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
        x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
        x5 = self.conv5(torch.cat((x, x1, x2, x3, x4), 1))
        # Empirical scaling factor 0.2
        return x5 * 0.2 + x


class RRDB(torch.nn.Module):
    """Residual in Residual Dense Block for RRDBNet."""

    def __init__(self, num_feat, num_grow_ch=32):
        super(RRDB, self).__init__()
        self.rdb1 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb2 = ResidualDenseBlock(num_feat, num_grow_ch)
        self.rdb3 = ResidualDenseBlock(num_feat, num_grow_ch)

    def forward(self, x):
        out = self.rdb1(x)
        out = self.rdb2(out)
        out = self.rdb3(out)
        return out * 0.2 + x


class RRDBNet(torch.nn.Module):
    def __init__(self, num_in_ch=3, num_out_ch=3, scale=4, num_feat=64, num_block=23, num_grow_ch=32):
        super(RRDBNet, self).__init__()
        self.scale = scale
        num_upsample = int(math.log(scale, 2))

        self.conv_first = torch.nn.Conv2d(num_in_ch, num_feat, 3, 1, 1)
        self.body = torch.nn.Sequential(*[RRDB(num_feat, num_grow_ch) for _ in range(num_block)])
        self.conv_body = torch.nn.Conv2d(num_feat, num_feat, 3, 1, 1)

        # Upsample
        self.conv_up1 = torch.nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_up2 = torch.nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_hr = torch.nn.Conv2d(num_feat, num_feat, 3, 1, 1)
        self.conv_last = torch.nn.Conv2d(num_feat, num_out_ch, 3, 1, 1)

        self.lrelu = torch.nn.LeakyReLU(negative_slope=0.2, inplace=True)

        # Initialization
        for m in self.modules():
            if isinstance(m, torch.nn.Conv2d):
                torch.nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')

    def forward(self, x):
        feat = self.conv_first(x)
        trunk = self.conv_body(self.body(feat))
        feat = feat + trunk

        # Upsample
        feat = self.lrelu(self.conv_up1(torch.nn.functional.interpolate(feat, scale_factor=2, mode='nearest')))
        feat = self.lrelu(self.conv_up2(torch.nn.functional.interpolate(feat, scale_factor=2, mode='nearest')))
        out = self.conv_last(self.lrelu(self.conv_hr(feat)))

        return out


class ESRGANInference(BaseImageInference):
    """ESRGAN-specific inference class"""

    def __init__(self, scale_factor=4, device=None):
        super().__init__(scale_factor=scale_factor, device=device)

    def load_model(self, model_path):
        """Load ESRGAN model from PyTorch weights (supports model name or path)"""
        # Resolve model path (supports both full paths and model names)
        from .utils import find_model_file
        try:
            resolved_path = find_model_file(model_path, model_type="pytorch")
            model_path = str(resolved_path)
        except FileNotFoundError:
            # If not found via finder, try as-is (might be a direct path)
            pass

        print(f'Loading ESRGAN model from {model_path}...')

        # Load weights first to detect architecture
        state_dict = torch.load(model_path, map_location='cpu', weights_only=False)

        # Handle different state dict formats
        if 'params_ema' in state_dict:
            print("Using params_ema from state dict")
            state_dict = state_dict['params_ema']
        elif 'params' in state_dict:
            print("Using params from state dict")
            state_dict = state_dict['params']

        # Detect model architecture from state dict
        conv_first_weight = state_dict.get('conv_first.weight', None)
        if conv_first_weight is not None:
            num_feat = conv_first_weight.shape[0]
            print(f'Detected model with {num_feat} feature channels')
        else:
            num_feat = 64  # Default fallback
            print(f'Could not detect feature channels, using default: {num_feat}')

        # Clean up state dict keys if needed
        if any('module.' in k for k in state_dict.keys()):
            new_state_dict = {}
            for k, v in state_dict.items():
                new_key = k.replace('module.', '') if k.startswith('module.') else k
                new_state_dict[new_key] = v
            state_dict = new_state_dict

        # Create model with detected architecture
        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=num_feat, num_block=23, num_grow_ch=32, scale=self.scale_factor)

        model.load_state_dict(state_dict, strict=False)
        model.eval()

        # Move model to the target device to avoid type mismatch
        model = model.to(self.device)
        print('✅ ESRGAN model loaded successfully!')

        self.model = model
        return model

    @classmethod
    def create_from_model_path(cls, model_path, scale_factor=4, device=None):
        """Factory method to create ESRGANInference from model path"""
        inference = cls(scale_factor=scale_factor, device=device)
        inference.load_model(model_path)
        return inference