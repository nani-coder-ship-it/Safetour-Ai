"""
SafeTour AI - Graph Attention Network (GATv2) for Road Segment Safety Prediction
--------------------------------------------------------------------------------
IEEE Research Architecture: Edge-Conditioned Multi-Head GATv2
Paper Contribution:
  - Dynamic attention weights conditioned on both intersection topology and road segment
    hazards (length, road class, flood risk, accident density).
  - Multi-hop attention diffusion across road corridors.
  - Edge-level prediction head predicting bounded safety scores in [0, 100].
"""

import warnings
warnings.filterwarnings("ignore", category=FutureWarning)
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch_geometric.nn import GATv2Conv


class RoadSafetyGAT(nn.Module):
    """
    Edge-Conditioned Graph Attention Network (GATv2) for predicting
    road segment safety scores from road network graph topology and hazards.
    """
    def __init__(
        self,
        node_in_dim=9,
        edge_in_dim=15,
        hidden_dim=64,
        num_heads=4,
        num_layers=2,
        dropout=0.1
    ):
        super(RoadSafetyGAT, self).__init__()

        self.node_in_dim = node_in_dim
        self.edge_in_dim = edge_in_dim
        self.hidden_dim = hidden_dim
        self.num_heads = num_heads
        self.num_layers = num_layers
        self.dropout = dropout

        # 1. Input Node Feature Encoder
        self.node_encoder = nn.Sequential(
            nn.Linear(node_in_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.LeakyReLU(0.2)
        )

        # 2. GATv2 Layers with Edge Conditioning
        self.gat_convs = nn.ModuleList()
        self.layer_norms = nn.ModuleList()

        head_dim = hidden_dim // num_heads

        for i in range(num_layers):
            conv = GATv2Conv(
                in_channels=hidden_dim,
                out_channels=head_dim,
                heads=num_heads,
                edge_dim=edge_in_dim,
                concat=True,
                dropout=dropout,
                add_self_loops=True
            )
            self.gat_convs.append(conv)
            self.layer_norms.append(nn.LayerNorm(hidden_dim))

        # 3. Edge Prediction Head (MLP)
        # Combines source node embedding (u), target node embedding (v), and edge attributes (e_uv)
        edge_repr_dim = (hidden_dim * 2) + edge_in_dim

        self.edge_predictor = nn.Sequential(
            nn.Linear(edge_repr_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, 32),
            nn.ReLU(),
            nn.Linear(32, 1)
        )

    def forward(self, x, edge_index, edge_attr, return_attention=False):
        """
        Forward pass.
        Args:
          x: Node features [N, node_in_dim]
          edge_index: Graph connectivity [2, M]
          edge_attr: Edge attributes [M, edge_in_dim]
          return_attention: If True, returns attention coefficients from layer 1

        Returns:
          pred_safety: Predicted safety score per edge [M, 1] in range [0, 100]
          att_weights (optional): Attention coefficients tuple (edge_index, alpha)
        """
        # Encode initial node representations
        h = self.node_encoder(x)

        att_weights = None

        # Message passing through GATv2 layers
        for i, (conv, norm) in enumerate(zip(self.gat_convs, self.layer_norms)):
            h_in = h
            if return_attention and i == 0:
                h_out, att = conv(h, edge_index, edge_attr=edge_attr, return_attention_weights=True)
                att_weights = att
            else:
                h_out = conv(h, edge_index, edge_attr=edge_attr)

            h = norm(h_in + F.elu(h_out))  # Residual connection + LayerNorm
            h = F.dropout(h, p=self.dropout, training=self.training)

        # Edge-level prediction: gather source (u) and target (v) representations
        u_idx = edge_index[0]
        v_idx = edge_index[1]

        h_u = h[u_idx]       # [M, hidden_dim]
        h_v = h[v_idx]       # [M, hidden_dim]

        # Concatenate [h_u || h_v || edge_attr]
        edge_repr = torch.cat([h_u, h_v, edge_attr], dim=-1)  # [M, 2*hidden_dim + edge_in_dim]

        # Predict raw score and scale through sigmoid to [0, 100]
        raw_pred = self.edge_predictor(edge_repr)
        pred_safety = 100.0 * torch.sigmoid(raw_pred)

        if return_attention:
            return pred_safety, att_weights
        return pred_safety


if __name__ == "__main__":
    # Smoke test model instantiation and forward pass
    model = RoadSafetyGAT(node_in_dim=9, edge_in_dim=15, hidden_dim=64, num_heads=4)
    print("=== GATv2 Model Architecture ===")
    print(model)

    # Dummy batch test
    dummy_x = torch.randn(10, 9)
    dummy_edges = torch.tensor([[0, 1, 2, 3], [1, 2, 3, 0]], dtype=torch.long)
    dummy_edge_attr = torch.randn(4, 15)

    pred, att = model(dummy_x, dummy_edges, dummy_edge_attr, return_attention=True)
    print(f"\nSmoke Test Output Shape: {pred.shape}")
    print(f"Sample Predictions: {pred.squeeze().tolist()}")
    print(f"Attention Weights Shape: {att[1].shape}")
