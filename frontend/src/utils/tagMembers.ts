export interface TagMemberLike {
  id?: number | null
  name: string
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface DisplayTagMember extends TagMemberLike {
  key: string
}

interface BuildDisplayTagMembersOptions {
  itemKey: string
  isTagged: boolean
  owner?: string
  taggedBy?: string
  taggedByMember?: TagMemberLike | null
  tags?: TagMemberLike[] | null
  excludeMemberId?: number | null
}

export function toDisplayTagMember(member: TagMemberLike, key: string): DisplayTagMember {
  return {
    key,
    id: member.id ?? null,
    name: member.name,
    hasProfilePhoto: member.hasProfilePhoto ?? false,
    profilePhotoVersion: member.profilePhotoVersion ?? 0,
  }
}

export function buildDisplayTagMembers(options: BuildDisplayTagMembersOptions): DisplayTagMember[] {
  const visibleTags = (options.tags ?? [])
    .filter((tag) => tag.name && tag.id !== options.excludeMemberId)
    .map((tag, index) =>
      toDisplayTagMember(tag, `tag-${tag.id ?? `${options.itemKey}-${index}`}`)
    )

  if (options.isTagged) {
    if (options.taggedByMember?.name) {
      const ownerTag = toDisplayTagMember(
        options.taggedByMember,
        `tagged-by-${options.taggedByMember.id ?? options.itemKey}`
      )

      if (!visibleTags.some((tag) => tag.id === ownerTag.id && tag.id != null)) {
        visibleTags.unshift(ownerTag)
      }
    } else {
      const fallbackName = options.taggedBy || options.owner
      if (fallbackName) {
        visibleTags.unshift({
          key: `tagged-by-${options.itemKey}`,
          id: null,
          name: fallbackName,
          hasProfilePhoto: false,
          profilePhotoVersion: 0,
        })
      }
    }
  }

  return visibleTags.filter((tag) => tag.name)
}
