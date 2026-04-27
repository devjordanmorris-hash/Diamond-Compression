Diamond Codec + thermal fingerprinting - Useful feature extractor for ai research pipelines free to use and modify.    See LICENSE” or add MIT/Apache-2.0       Requirements: Swift, Metal, macOS.

## Status

This is an experimental research prototype. The implementation is intended for exploration, benchmarking, and collaboration rather than production use.

## License

Free to use, modify, and integrate under the repository license.

# Diamond Compression

**A bucketed, path-based predictive image representation with compact residual encoding and thermal fingerprinting.**

Experimental research prototype for image compression, feature extraction, and fast structural similarity matching.

A Bucketed, Path-Based Predictive Image Representation with Compact Residual Encoding

Overview

Diamond Codec is a structured image encoding and feature extraction pipeline that combines:

* coarse colour bucketing
* path-based spatial encoding
* predictive residual compression
* GPU-assisted preprocessing
* post-merge structural optimisation

The system transforms raw image data into a compact, structured representation that preserves spatial and colour locality while reducing redundancy.

It is designed for:

* high-throughput preprocessing
* feature extraction pipelines
* approximate reconstruction
* performance-sensitive compute workflows

⸻

Core Idea

Instead of encoding images in raster order, Diamond Codec:

1. Groups pixels by coarse colour similarity
2. Encodes spatial traversal paths within each group
3. Stores compact residuals relative to a rolling base
4. Reconstructs data via predictive chaining

This results in a representation that is:

structured, locality-aware, and computationally efficient

⸻

Architecture

1. Diamond Representation

Each pixel is represented as:

* RGB (UInt8)
* optional metadata hooks (shape, orient)

⸻

2. Colour Bucketing

Pixels are assigned to coarse buckets: bucketID = (r >> 6, g >> 6, b >> 6)

This reduces entropy and enables shared bases for encoding.
3. Dictionary Entries

Each bucket produces one or more DiamondDictionaryEntry objects:

* base → representative colour (mean)
* firstPosition → anchor pixel
* deltaPositions → spatial path (dx, dy)
* residuals → compact colour differences

These entries form the core encoding units.

4. Spatial Path Encoding

Pixels are encoded as relative movements: (x₀, y₀) → (x₁, y₁) → (x₂, y₂)
Stored as: (dx, dy)
Advantages:

* preserves locality
* avoids raster redundancy
* compact representation

* 5. Predictive Residual Encoding

Colour differences are encoded as signed 5-bit values: ΔR, ΔG, ΔB ∈ [-16, +15]
Packed into 15 bits: | r5 | g5 | b5 |
Each residual is applied relative to a rolling base, forming a predictive chain.
6. Rolling Reconstruction Model

Decoding follows:

1. Start from base colour
2. Apply residual
3. Update base
4. Move along path

This produces a continuous reconstruction with minimal stored data.

⸻

7. GPU Preprocessing (Metal)

A GPU kernel performs per-pixel preprocessing:

* extracts bucketID
* computes residuals (relative to neutral base)
* outputs compact representation

Properties:

* fully parallel
* deterministic
* aligned with CPU pipeline

⸻

8. Post-Merge Optimisation

Dictionary entries are merged when:

* same bucket
* identical base

Process:

1. Reconstruct pixel chains
2. Combine
3. Re-sort spatially
4. Rebuild path + residual stream

This reduces fragmentation and improves compression efficiency.

⸻

9. Visualisation

A renderer is included to:

* display bucket clusters
* visualise spatial paths
* inspect structure of encoded data

Useful for:

* debugging
* qualitative analysis
* research exploration

⸻

Pipeline Summary

Encoding
Image → Bucketing → Sorting → Base Selection
     → Path Encoding → Residual Encoding → Dictionary
     Optional GPU Stage
     Pixels → GPU preprocess → bucket + residual hints

     Decoding 
     Dictionary → Path traversal → Residual application → Image

     Optimisation
     Dictionary → Merge → Rebuild → Compact dictionary

     Properties

Compression Behaviour

* Reduces colour redundancy (bucketing)
* Reduces spatial redundancy (paths)
* Uses compact 15-bit residuals

Compute Characteristics

* integer-heavy operations
* branch-light decode
* GPU-friendly preprocessing
* cache-friendly sequential access

⸻

Use Cases

* Image feature extraction
* Preprocessing for ML pipelines
* Simulation / modelling acceleration
* Data reduction in large-scale workflows
* Experimental codecs and representations

⸻

Advantages

* Structured, interpretable representation
* High locality preservation
* Efficient decode path
* GPU + CPU hybrid design
* Modular pipeline

⸻

Limitations

* Lossy (quantised residuals)
* Path ordering may impact efficiency
* Not optimised for perceptual compression
* GPU residuals currently use fixed neutral base

⸻

Future Work

* adaptive bucket sizing
* improved path generation (e.g. space-filling curves)
* SIMD / vectorised decode
* learned residual prediction
* GPU chain-compatible residual encoding
* utilisation of shape/orientation metadata

⸻

License

Free to use, modify, and integrate.
No restrictions.

⸻

Notes

Diamond Codec is designed as a performance-oriented structured representation, not a replacement for traditional codecs.

Its strength lies in:

combining structure, locality, and computational efficiency

⸻

Thermal Fingerprinting

Compact Structural Image Descriptor for Fast Similarity Matching

⸻

Overview

Thermal Fingerprinting is a lightweight image descriptor that encodes global and local structure into a fixed 64-bit representation.

The method is designed for:

* fast image similarity search
* dataset deduplication
* approximate visual matching
* GPU-accelerated retrieval

It provides a balance between:

compactness, interpretability, and computational efficiency

⸻

Core Idea

An image is divided into a 4 × 4 grid (16 tiles).

Each tile contributes a 4-bit descriptor capturing:

* relative intensity
* local contrast
* dominant structural direction

Total:16 tiles × 4 bits = 64-bit fingerprint
Tile Encoding

Each tile produces a 4-bit value: 
[ direction | contrast | intensity (2 bits) ]

Bit Breakdown

* Bits 0–1 (Intensity Band)
    Quantised relative to global image average
* Bit 2 (Contrast Flag)
    Indicates high local variation within the tile
* Bit 3 (Direction Flag)
    Captures dominant structural bias:
    * diagonal (top-left vs bottom-right)
    * or axial (horizontal / vertical)

⸻

Feature Extraction

For each tile, the following are computed:

* average luminance
* minimum / maximum luminance
* directional energy:
    * diagonal split
    * horizontal split
    * vertical split

The strongest directional signal is selected to form the direction flag.

⸻

Global Normalisation

A global luminance average is computed across the entire image.

Tile intensities are expressed relative to this average to ensure:

* consistency across images
* robustness to brightness shifts

⸻

GPU Acceleration

Thermal Fingerprinting is designed for GPU execution using Metal.

Processing Stages

1. Global Reduction
    * computes total luminance
    * derives global average
2. Tile Statistics
    * computes per-tile features:
        * intensity
        * contrast
        * directional energy
3. Fingerprint Packing
    * converts tile data into a 64-bit descriptor

⸻

Matching

Similarity between fingerprints is computed per tile:
score = band similarity + contrast match + direction match

Where:

* band similarity is distance-based
* contrast and direction are binary matches

Total score is summed across all 16 tiles.

⸻

Properties

Compactness

* fixed 64-bit representation
* constant memory footprint

Speed

* fast integer operations
* GPU-parallel matching

Interpretability

* each bit has a clear meaning
* structure-aware descriptor

⸻

Use Cases

* large-scale image indexing
* near-duplicate detection
* content-based retrieval
* fast filtering before heavier models
* hybrid pipelines (pre-ML filtering)

⸻

Advantages

* extremely compact descriptor
* fast similarity scoring
* captures structural information
* robust to minor noise and variation
* GPU-friendly design

⸻

Limitations

* coarse spatial resolution (4×4 grid)
* not fully invariant to rotation/scale
* may miss fine-grained texture differences

⸻

Future Work

* rotation and scale invariance
* adaptive tile layouts
* multi-scale fingerprints
* integration with learned features
* tighter coupling with Diamond representations

⸻

License

Free to use, modify, and integrate.

⸻

Notes

Thermal Fingerprinting is intended as a:

fast, first-pass structural similarity filter

It complements—not replaces—more detailed analysis methods.















Contact

Open to collaboration, testing, and research exploration. dev.jordanmorris@gmail.com
