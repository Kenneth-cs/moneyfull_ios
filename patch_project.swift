            let finalTrendData = localTrendData
            await MainActor.run {
                self._projectCategorySegments = categorySegments
                self._projectTotalExpense = totalExpense
                self._projectTrendData = finalTrendData
            }
