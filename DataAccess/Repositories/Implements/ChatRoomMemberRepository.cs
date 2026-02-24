using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implements;

public sealed class ChatRoomMemberRepository : IChatRoomMemberRepository
{
    private readonly SchoolManagementDbContext _context;

    public ChatRoomMemberRepository(SchoolManagementDbContext context)
    {
        _context = context;
    }

    public async Task<ChatRoomMember?> GetMembershipAsync(int roomId, int userId)
    {
        return await _context.ChatRoomMembers
            .FirstOrDefaultAsync(m => m.RoomId == roomId && m.UserId == userId);
    }

    public async Task<ChatRoomMember> UpsertMembershipAsync(int roomId, int userId, string roleInRoom, string memberStatus)
    {
        var existing = await _context.ChatRoomMembers
            .FirstOrDefaultAsync(m => m.RoomId == roomId && m.UserId == userId);

        if (existing is not null)
        {
            existing.RoleInRoom = roleInRoom;
            existing.MemberStatus = memberStatus;
            await _context.SaveChangesAsync();
            return existing;
        }

        var member = new ChatRoomMember
        {
            RoomId = roomId,
            UserId = userId,
            RoleInRoom = roleInRoom,
            MemberStatus = memberStatus,
            JoinedAt = DateTime.UtcNow
        };
        _context.ChatRoomMembers.Add(member);
        await _context.SaveChangesAsync();
        return member;
    }

    public async Task UpdateLastReadMessageIdAsync(int roomId, int userId, long lastReadMessageId)
    {
        var member = await _context.ChatRoomMembers
            .FirstOrDefaultAsync(m => m.RoomId == roomId && m.UserId == userId);

        if (member is not null)
        {
            member.LastReadMessageId = lastReadMessageId;
            await _context.SaveChangesAsync();
        }
    }

    public async Task UpdateMemberStatusAsync(int roomId, int userId, string newStatus)
    {
        var member = await _context.ChatRoomMembers
            .FirstOrDefaultAsync(m => m.RoomId == roomId && m.UserId == userId);

        if (member is not null)
        {
            member.MemberStatus = newStatus;
            await _context.SaveChangesAsync();
        }
    }
}
