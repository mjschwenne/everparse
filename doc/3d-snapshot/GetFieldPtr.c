

#include "GetFieldPtr.h"

uint64_t
GetFieldPtrValidateT(
  uint8_t **Out,
  uint8_t *Ctxt,
  void
  (*ErrorHandlerFn)(
    EVERPARSE_STRING x0,
    EVERPARSE_STRING x1,
    EVERPARSE_STRING x2,
    uint64_t x3,
    uint8_t *x4,
    uint8_t *x5,
    uint64_t x6
  ),
  uint8_t *Input,
  uint64_t InputLength,
  uint64_t StartPosition
)
{
  /* Validating field f1 */
  BOOLEAN hasEnoughBytes0 = (uint64_t)(uint32_t)10U <= (InputLength - StartPosition);
  uint64_t positionAfterT;
  if (!hasEnoughBytes0)
  {
    positionAfterT =
      EverParseSetValidatorErrorPos(EVERPARSE_VALIDATOR_ERROR_NOT_ENOUGH_DATA,
        StartPosition);
  }
  else
  {
    uint8_t *truncatedInput = Input;
    uint64_t truncatedInputLength = StartPosition + (uint64_t)(uint32_t)10U;
    uint64_t result = StartPosition;
    while (TRUE)
    {
      uint64_t position = result;
      BOOLEAN ite;
      if (!(1ULL <= (truncatedInputLength - position)))
      {
        ite = TRUE;
      }
      else
      {
        /* Checking that we have enough space for a UINT8, i.e., 1 byte */
        BOOLEAN hasBytes = 1ULL <= (truncatedInputLength - position);
        uint64_t positionAfterT0;
        if (hasBytes)
        {
          positionAfterT0 = position + 1ULL;
        }
        else
        {
          positionAfterT0 =
            EverParseSetValidatorErrorPos(EVERPARSE_VALIDATOR_ERROR_NOT_ENOUGH_DATA,
              position);
        }
        uint64_t res;
        if (EverParseIsSuccess(positionAfterT0))
        {
          res = positionAfterT0;
        }
        else
        {
          ErrorHandlerFn("_T",
            "f1.element",
            EverParseErrorReasonOfResult(positionAfterT0),
            EverParseGetValidatorErrorKind(positionAfterT0),
            Ctxt,
            truncatedInput,
            position);
          res = positionAfterT0;
        }
        uint64_t result1 = res;
        result = result1;
        ite = EverParseIsError(result1);
      }
      if (ite)
      {
        break;
      }
    }
    uint64_t res = result;
    positionAfterT = res;
  }
  uint64_t positionAfterf1;
  if (EverParseIsSuccess(positionAfterT))
  {
    positionAfterf1 = positionAfterT;
  }
  else
  {
    ErrorHandlerFn("_T",
      "f1",
      EverParseErrorReasonOfResult(positionAfterT),
      EverParseGetValidatorErrorKind(positionAfterT),
      Ctxt,
      Input,
      StartPosition);
    positionAfterf1 = positionAfterT;
  }
  if (EverParseIsError(positionAfterf1))
  {
    return positionAfterf1;
  }
  /* Validating field f2 */
  BOOLEAN hasEnoughBytes = (uint64_t)(uint32_t)20U <= (InputLength - positionAfterf1);
  uint64_t positionAfterT0;
  if (!hasEnoughBytes)
  {
    positionAfterT0 =
      EverParseSetValidatorErrorPos(EVERPARSE_VALIDATOR_ERROR_NOT_ENOUGH_DATA,
        positionAfterf1);
  }
  else
  {
    uint8_t *truncatedInput = Input;
    uint64_t truncatedInputLength = positionAfterf1 + (uint64_t)(uint32_t)20U;
    uint64_t result = positionAfterf1;
    while (TRUE)
    {
      uint64_t position = result;
      BOOLEAN ite;
      if (!(1ULL <= (truncatedInputLength - position)))
      {
        ite = TRUE;
      }
      else
      {
        /* Checking that we have enough space for a UINT8, i.e., 1 byte */
        BOOLEAN hasBytes = 1ULL <= (truncatedInputLength - position);
        uint64_t positionAfterT1;
        if (hasBytes)
        {
          positionAfterT1 = position + 1ULL;
        }
        else
        {
          positionAfterT1 =
            EverParseSetValidatorErrorPos(EVERPARSE_VALIDATOR_ERROR_NOT_ENOUGH_DATA,
              position);
        }
        uint64_t res;
        if (EverParseIsSuccess(positionAfterT1))
        {
          res = positionAfterT1;
        }
        else
        {
          ErrorHandlerFn("_T",
            "f2.base.element",
            EverParseErrorReasonOfResult(positionAfterT1),
            EverParseGetValidatorErrorKind(positionAfterT1),
            Ctxt,
            truncatedInput,
            position);
          res = positionAfterT1;
        }
        uint64_t result1 = res;
        result = result1;
        ite = EverParseIsError(result1);
      }
      if (ite)
      {
        break;
      }
    }
    uint64_t res = result;
    positionAfterT0 = res;
  }
  uint64_t positionAfterf2;
  if (EverParseIsSuccess(positionAfterT0))
  {
    positionAfterf2 = positionAfterT0;
  }
  else
  {
    ErrorHandlerFn("_T",
      "f2.base",
      EverParseErrorReasonOfResult(positionAfterT0),
      EverParseGetValidatorErrorKind(positionAfterT0),
      Ctxt,
      Input,
      positionAfterf1);
    positionAfterf2 = positionAfterT0;
  }
  uint64_t positionAfterT1;
  if (EverParseIsSuccess(positionAfterf2))
  {
    uint8_t *hd = Input + (uint32_t)positionAfterf1;
    *Out = hd;
    BOOLEAN actionSuccessF2 = TRUE;
    if (!actionSuccessF2)
    {
      positionAfterT1 =
        EverParseSetValidatorErrorPos(EVERPARSE_VALIDATOR_ERROR_ACTION_FAILED,
          positionAfterf2);
    }
    else
    {
      positionAfterT1 = positionAfterf2;
    }
  }
  else
  {
    positionAfterT1 = positionAfterf2;
  }
  if (EverParseIsSuccess(positionAfterT1))
  {
    return positionAfterT1;
  }
  ErrorHandlerFn("_T",
    "f2",
    EverParseErrorReasonOfResult(positionAfterT1),
    EverParseGetValidatorErrorKind(positionAfterT1),
    Ctxt,
    Input,
    positionAfterf1);
  return positionAfterT1;
}

