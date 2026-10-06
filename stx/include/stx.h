#ifndef __STX_H__
#define __STX_H__

#include <stdint.h>
#include <stdbool.h>

typedef enum
{
  STX_KIND_PC,
  STX_KIND_PS2
} StxKind;

typedef struct
{
  uint32_t  version;
  uint32_t  width, height;
  StxKind   kind;
  char     *pixels;
  uint32_t *palette;
  uint16_t  color_count;
} StxDocumentInit;

typedef struct
{
  size_t pos;
  const char *message;
} StxValidationError;

typedef struct StxReadState StxReadState;
typedef struct StxDocument StxDocument;
typedef struct StxTexture StxTexture;

StxReadState       *stx_read_state_init           (void);
/**
 * Initializes an error buffer for collecting validation messages during
 * parsing. No more than @p capacity errors will be collected.
 */
bool                stx_read_state_collect_errors (StxReadState *state,
                                                   size_t        capacity);
StxValidationError *stx_read_state_errors         (StxReadState *state);
size_t              stx_read_state_error_count    (StxReadState *state);
void                stx_read_state_free           (StxReadState *state);

/**
 * Creates an STX document based on the values given in @p init.
 *
 * All the values that are passed through @p init will be owned by the newly
 * created document.
 *
 * The function returns NULL when some essential fields (e.g. pixels or
 * palette for PS2) are missing. Also, the @p color_count needs to be between
 * 1 and 256 (inclusive).
 *
 * @param init struct that contains values for the document
 * @return a newly created STX document or NULL in case of an error.
 */
StxDocument *stx_document_create      (const StxDocumentInit *init);

void         stx_document_free        (StxDocument *doc);

/**
 * Gets the version number of the document.
 *
 * @param doc STX document
 * @return version number or zero when the metadata section is not presented.
 */
uint32_t     stx_document_get_version (const StxDocument *doc);

StxDocument *stx_document_read        (const char   *buf,
                                       size_t        length,
                                       StxReadState *state,
                                       uint16_t     *error);

/**
 * Estimates the size of the STX document in bytes when written out.
 *
 * @param doc STX document
 * @return size in bytes
 */
size_t       stx_document_estimate_size (StxDocument *doc);
/**
 * Writes the STX document to a preallocated buffer.
 *
 * @param[in]  doc      STX document
 * @param[out] buffer   preallocated byte buffer
 * @param[in]  capacity capacity of @p buffer
 * @param[out] length   count of bytes written
 *
 * @return TRUE on success
 */
bool         stx_document_write_buffer  (StxDocument *doc,
                                         char        *buffer,
                                         size_t       capacity,
                                         size_t      *length);

StxTexture  *stx_document_get_texture (StxDocument *doc);

/**
 * Gets the kind of the texture (PC or PS2).
 * @param tx texture
 * @return texture kind
 */
StxKind      stx_texture_kind         (StxTexture *tx);
char        *stx_texture_get_data     (StxTexture *tx,
                                       size_t     *width,
                                       size_t     *height);
/**
 * Gets the palette of the texture.
 *
 * Each color is represented as RGBA with 8 bits per channel.
 *
 * @param      tx           texture
 * @param[out] color_count  number of colors in the pallete. Set to NULL
                            if not needed.
 *
 * @return a pointer to the first color in the palette.
 */
uint32_t    *stx_texture_get_palette  (StxTexture *tx,
                                       size_t     *color_count);

const char  *stx_error_string (uint16_t error);

#endif /* __STX_H__ */
