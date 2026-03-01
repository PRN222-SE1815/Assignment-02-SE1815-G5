namespace BusinessLogic.DTOs.Response;

public class ServiceResult
{
    public bool IsSuccess { get; set; }
    public string? ErrorCode { get; set; }
    public string? Message { get; set; }

    public static ServiceResult Success(string? message = null)
    {
        return new ServiceResult
        {
            IsSuccess = true,
            Message = message
        };
    }

    public static ServiceResult Fail(string errorCode, string message)
    {
        return new ServiceResult
        {
            IsSuccess = false,
            ErrorCode = errorCode,
            Message = message
        };
    }
}

public sealed class ServiceResult<T>
{
    public bool IsSuccess { get; set; }
    public string? ErrorCode { get; set; }
    public string? Message { get; set; }
    public T? Data { get; set; }

    public static ServiceResult<T> Success(T data, string? message = null)
    {
        return new ServiceResult<T>
        {
            IsSuccess = true,
            Data = data,
            Message = message
        };
    }

    public static ServiceResult<T> Fail(string errorCode, string message)
    {
        return new ServiceResult<T>
        {
            IsSuccess = false,
            ErrorCode = errorCode,
            Message = message
        };
    }

    public static ServiceResult<T> Fail(string errorCode, string message, T data)
    {
        return new ServiceResult<T>
        {
            IsSuccess = false,
            ErrorCode = errorCode,
            Message = message,
            Data = data
        };
    }
}
