Diamond Codec

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

Contact

Open to collaboration, testing, and research exploration. dev.jordanmorris@gmail.com
