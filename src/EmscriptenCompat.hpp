#ifndef EMSCRIPTEN_COMPAT_HPP
#define EMSCRIPTEN_COMPAT_HPP

#include <cstring>
#include <type_traits>

// Define empty stubs for libraries not available in Emscripten
#ifdef __EMSCRIPTEN__

// Provide a bit_cast implementation if std::bit_cast is not available
namespace std {
    template <typename To, typename From>
    typename std::enable_if<
        sizeof(To) == sizeof(From) &&
        std::is_trivially_copyable<From>::value &&
        std::is_trivially_copyable<To>::value,
        To>::type
    bit_cast(const From& src) noexcept {
        To dst;
        std::memcpy(&dst, &src, sizeof(To));
        return dst;
    }
}

// Undefine problematic macros
#ifdef PAGE_SIZE
#undef PAGE_SIZE
#endif

// TurboJPEG stubs
typedef void* tjhandle;
#define TJPF_RGB 0
#define TJPF_RGBX 1
#define TJPF_UNKNOWN 99
#define TJSAMP_444 0
#define TJSAMP_422 1
#define TJSAMP_420 2
#define TJINIT_COMPRESS 0
#define TJPARAM_QUALITY 0
#define TJPARAM_SUBSAMP 1
#define TJPARAM_JPEGWIDTH 2
#define TJPARAM_JPEGHEIGHT 3

inline tjhandle tj3Init(int initType) { return nullptr; }
inline int tj3Set(tjhandle handle, int param, int value) { return 0; }
inline int tj3Compress8(tjhandle handle, const unsigned char* srcBuf, int width, int pitch, int height, int pixelFormat, unsigned char** jpegBuf, size_t* jpegSize) { return 0; }
inline int tj3Decompress8(tjhandle handle, const unsigned char* jpegBuf, size_t jpegSize, unsigned char* dstBuf, int pitch, int pixelFormat) { return 0; }
inline void tj3Destroy(tjhandle handle) {}
inline const char* tj3GetErrorStr(tjhandle handle) { return "TurboJPEG not supported in WebAssembly"; }
inline void tjDestroy(tjhandle handle) {}
inline unsigned long tjBufSize(int width, int height, int jpegSubsamp) { return width * height * 4; }

// AVIF stubs
typedef struct avifRGBImage {
    int width;
    int height;
    int depth;
    int format;
    int chromaUpsampling;
    int chromaDownsampling;
    int avoidLibYUV;
    int ignoreAlpha;
    int alphaPremultiplied;
    int isFloat;
    int maxThreads;
    unsigned char* pixels;
    int rowBytes;
} avifRGBImage;

typedef struct avifImage avifImage;
typedef struct avifEncoder avifEncoder;
typedef struct avifDecoder avifDecoder;
typedef struct avifRWData {
    unsigned char* data;
    size_t size;
} avifRWData;

#define AVIF_DATA_EMPTY { NULL, 0 }
#define AVIF_RGB_FORMAT_RGB 0
#define AVIF_RGB_FORMAT_RGBA 1
#define AVIF_RGB_FORMAT_BGR 2
#define AVIF_RGB_FORMAT_BGRA 3
#define AVIF_RGB_FORMAT_COUNT 4
#define AVIF_PIXEL_FORMAT_YUV444 0
#define AVIF_PIXEL_FORMAT_YUV422 1
#define AVIF_PIXEL_FORMAT_YUV420 2
#define AVIF_RESULT_OK 0
#define AVIF_FALSE 0
#define AVIF_TRUE 1
#define AVIF_ADD_IMAGE_FLAG_SINGLE 0

typedef int avifResult;

inline avifImage* avifImageCreate(int width, int height, int depth, int yuvFormat) { return nullptr; }
inline void avifImageDestroy(avifImage* image) {}
inline void avifRGBImageSetDefaults(avifRGBImage* rgb, const avifImage* image) {}
inline avifResult avifImageRGBToYUV(avifImage* image, const avifRGBImage* rgb) { return AVIF_RESULT_OK; }
inline avifEncoder* avifEncoderCreate() { return nullptr; }
inline void avifEncoderDestroy(avifEncoder* encoder) {}
inline avifResult avifEncoderAddImage(avifEncoder* encoder, avifImage* image, int durationInTimescales, int addImageFlags) { return AVIF_RESULT_OK; }
inline avifResult avifEncoderFinish(avifEncoder* encoder, avifRWData* output) { return AVIF_RESULT_OK; }
inline void avifRWDataFree(avifRWData* raw) {}
inline avifDecoder* avifDecoderCreate() { return nullptr; }
inline void avifDecoderDestroy(avifDecoder* decoder) {}
inline avifResult avifDecoderSetIOMemory(avifDecoder* decoder, const unsigned char* data, size_t size) { return AVIF_RESULT_OK; }
inline avifResult avifDecoderParse(avifDecoder* decoder) { return AVIF_RESULT_OK; }
inline avifResult avifDecoderNextImage(avifDecoder* decoder) { return AVIF_RESULT_OK; }
inline avifResult avifImageYUVToRGB(const avifImage* image, avifRGBImage* rgb) { return AVIF_RESULT_OK; }
inline const char* avifResultToString(avifResult result) { return "AVIF not supported in WebAssembly"; }

// Vulkan stubs
namespace IrisCore {
    namespace Vulkan {
        class Device {
        public:
            static bool isVulkanAvailable() { return false; }
        };
    }
}

// Define WebAssembly-compatible page size
const size_t IRIS_PAGE_SIZE = 16384;

#else
// For non-Emscripten builds, include the real headers
#include <turbojpeg.h>
#include <avif/avif.h>
#include <vk_mem_alloc.h>
const size_t IRIS_PAGE_SIZE = getpagesize();
#endif

#endif // EMSCRIPTEN_COMPAT_HPP
