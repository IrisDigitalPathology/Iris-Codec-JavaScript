#include <sstream>
#include "IrisCodecPriv.hpp"

#ifdef __EMSCRIPTEN__
#include "EmscriptenCompat.hpp"
#else
#include "IrisCoreVulkan.hpp"
#include <turbojpeg.h>
#include <avif/avif.h>
#endif

namespace IrisCodec {

#if defined(EMSCRIPTEN)
// Simplified implementations for Emscripten

__INTERNAL__Context::__INTERNAL__Context(const ContextCreateInfo& info) :
    _device(nullptr),
    _gpuAV1Encode(false),
    _gpuAV1Decode(false)
{
    // No initialization needed for Emscripten
}

__INTERNAL__Context::~__INTERNAL__Context()
{
    // No cleanup needed for Emscripten
}

Buffer __INTERNAL__Context::compress_tile(const CompressTileInfo& info)
{
    // For Emscripten, just return a copy of the input buffer
    return Copy_strong_buffer_from_data(info.pixelArray->data(), info.pixelArray->size());
}

Buffer __INTERNAL__Context::decompress_tile(const DecompressTileInfo& info)
{
    // For Emscripten, just return a copy of the input buffer
    return Copy_strong_buffer_from_data(info.compressed->data(), info.compressed->size());
}

#else
// Original implementation for non-Emscripten platforms
// ...
#endif

} // END IRIS CODEC NAMESPACE
